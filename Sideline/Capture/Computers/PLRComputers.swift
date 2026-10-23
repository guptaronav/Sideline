// PLRComputers.swift
// Pupillary Light Reflex measurement — three signals sharing a rolling
// pupil-diameter buffer + stimulus-event triggers:
//   - plr_amplitude_v1       baseline diameter - min diameter post-onset
//   - plr_latency_v1         time from onset to start of constriction
//   - constriction_velocity_v1  max -dD/dt during constriction phase
//
// Each computer subscribes to both .cameraFrame and .stimulusEvent.
//   cameraFrame  → append latest pupil diameter (from engine.values, where
//                 PupilDiameterBaselineV1 just published it) into a 5 s buffer
//   stimulusEvent (non-dark color, onset) → start a response window:
//        - baseline = median diameter in 500 ms pre-onset
//        - track min + slope in 2 s post-onset
//        - publish results when window closes
//
// PLR is only measurable when both the camera AND stimulus are running.
// That's S07 (Full Integration). S06 alone has stimulus but no camera, so
// these signals stay quiet there.

import Foundation

@MainActor
private final class PLRWindow {
    /// (timestamp, diameter mm)
    var buffer: [(t: TimeInterval, d: Double)] = []
    static let bufferSeconds: TimeInterval = 5.0

    /// Active response measurement state. Non-nil after an onset event,
    /// nil after the response window has been published.
    struct Active {
        let onsetTs: TimeInterval
        let baseline: Double
        var minDiameter: Double
        var minDiameterTs: TimeInterval
        /// Most negative slope dD/dt observed during the response.
        var maxNegSlope: Double
        var prev: (t: TimeInterval, d: Double)
    }
    var active: Active?

    static let responseWindowSec: TimeInterval = 2.0
    static let preBaselineWindowSec: TimeInterval = 0.5
    /// Diameter must dip at least this much below baseline before we count
    /// it as the start of constriction.
    ///
    /// Threshold tuning — 0.05 mm was wrong:
    /// ------------------------------------------------------------
    /// The pupil-diameter signal uses dark-pixel luma threshold
    /// segmentation on the ARKit YCbCr Y plane. Its sample-to-sample
    /// noise floor is ~0.15-0.3 mm (driven by iris-pigmentation
    /// bleed, screen specular highlights, sub-pixel ROI quantisation).
    /// A 0.05 mm dip threshold sits INSIDE this noise band — random
    /// jitter would trigger onset detection on the first frame
    /// after the stimulus regardless of true pupillary response,
    /// biasing latency strongly toward zero and producing false
    /// positives on every flash.
    ///
    /// 0.20 mm is approximately 3× the per-sample noise σ — i.e.
    /// a 3-σ detection criterion, which is the standard threshold
    /// in pupillographic literature for declaring a genuine onset
    /// (Bremner 2009; Mathôt 2018). Real PLR constrictions are
    /// 0.5-1.5 mm in amplitude even at our weak screen-flash
    /// stimulus, so 0.20 mm is well below the response amplitude
    /// while above the noise band.
    static let constrictionThresholdMm: Double = 0.20

    func appendDiameter(t: TimeInterval, d: Double) {
        buffer.append((t, d))
        while let f = buffer.first, t - f.t > Self.bufferSeconds {
            buffer.removeFirst()
        }
        // Update active response if we're in a window.
        if var a = active {
            // Update min.
            if d < a.minDiameter { a.minDiameter = d; a.minDiameterTs = t }
            // Update slope.
            let dt = t - a.prev.t
            if dt > 0 {
                let slope = (d - a.prev.d) / dt
                if slope < a.maxNegSlope { a.maxNegSlope = slope }
            }
            a.prev = (t, d)
            active = a
        }
    }

    func startWindow(onsetTs: TimeInterval) {
        // Take median diameter in last 0.5 s as baseline.
        // Include the sample at exactly onsetTs (>= 0, not > 0).
        let preSamples = buffer.filter {
            onsetTs - $0.t < Self.preBaselineWindowSec && onsetTs - $0.t >= 0
        }
        .map { $0.d }
        guard preSamples.count >= 3 else { return }
        let sorted = preSamples.sorted()
        // True median: average of the two middle elements for even
        // counts, otherwise the middle element. The previous
        // `sorted[count/2]` always rounded UP, biasing the baseline
        // high and deflating plr_amplitude_v1 by ~1 % at the minimum
        // pre-stim window.
        let mid = sorted.count / 2
        let baseline = sorted.count % 2 == 0
            ? (sorted[mid - 1] + sorted[mid]) / 2.0
            : sorted[mid]
        let startD = buffer.last?.d ?? baseline
        let startT = buffer.last?.t ?? onsetTs
        active = Active(onsetTs: onsetTs,
                        baseline: baseline,
                        minDiameter: baseline,
                        minDiameterTs: onsetTs,
                        maxNegSlope: 0,
                        prev: (startT, startD))
    }

    /// If the response window has closed (now − onsetTs >= 2 s) and we have
    /// an active window, returns the result and clears the window.
    func maybeFinalize(now: TimeInterval) -> Active? {
        guard let a = active else { return nil }
        if now - a.onsetTs >= Self.responseWindowSec {
            active = nil
            return a
        }
        return nil
    }
}

// MARK: - plr_amplitude_v1

@MainActor
final class PLRAmplitudeV1: SignalComputer {
    static let signalId: String = "plr_amplitude_v1"
    static let sampleKinds: Set<SignalSampleKind> = [.cameraFrame, .stimulusEvent]

    private let window = PLRWindow()

    func consume(_ sample: SignalSample, engine: SignalEngine) {
        switch sample {
        case let .cameraFrame(_, _, _, _, _, _, ts):
            if let d = engine.values["pupil_diameter_baseline_v1"] {
                window.appendDiameter(t: ts, d: d)
            }
            if let done = window.maybeFinalize(now: ts) {
                let amp = max(0, done.baseline - done.minDiameter)
                engine.publish(Self.signalId, value: amp, timestamp: ts)
            }
        case let .stimulusEvent(color, isOnset, ts):
            if isOnset, color != "dark" { window.startWindow(onsetTs: ts) }
        default: break
        }
    }
}

// MARK: - plr_latency_v1

@MainActor
final class PLRLatencyV1: SignalComputer {
    static let signalId: String = "plr_latency_v1"
    static let sampleKinds: Set<SignalSampleKind> = [.cameraFrame, .stimulusEvent]

    private let window = PLRWindow()

    func consume(_ sample: SignalSample, engine: SignalEngine) {
        switch sample {
        case let .cameraFrame(_, _, _, _, _, _, ts):
            if let d = engine.values["pupil_diameter_baseline_v1"] {
                window.appendDiameter(t: ts, d: d)
                if var a = window.active {
                    // First sample where d falls below baseline - threshold
                    // determines the latency.
                    if a.minDiameterTs == a.onsetTs,
                       d < a.baseline - PLRWindow.constrictionThresholdMm {
                        a.minDiameterTs = ts
                        window.active = a
                    }
                }
            }
            if let done = window.maybeFinalize(now: ts) {
                if done.minDiameterTs > done.onsetTs {
                    let latencyMs = (done.minDiameterTs - done.onsetTs) * 1000.0
                    engine.publish(Self.signalId, value: latencyMs, timestamp: ts)
                }
            }
        case let .stimulusEvent(color, isOnset, ts):
            if isOnset, color != "dark" { window.startWindow(onsetTs: ts) }
        default: break
        }
    }
}

// MARK: - constriction_velocity_v1

@MainActor
final class ConstrictionVelocityV1: SignalComputer {
    static let signalId: String = "constriction_velocity_v1"
    static let sampleKinds: Set<SignalSampleKind> = [.cameraFrame, .stimulusEvent]

    private let window = PLRWindow()

    func consume(_ sample: SignalSample, engine: SignalEngine) {
        switch sample {
        case let .cameraFrame(_, _, _, _, _, _, ts):
            if let d = engine.values["pupil_diameter_baseline_v1"] {
                window.appendDiameter(t: ts, d: d)
            }
            if let done = window.maybeFinalize(now: ts) {
                // maxNegSlope is in mm/s (negative). Report magnitude.
                let v = -done.maxNegSlope
                if v > 0 {
                    engine.publish(Self.signalId, value: v, timestamp: ts)
                }
            }
        case let .stimulusEvent(color, isOnset, ts):
            if isOnset, color != "dark" { window.startWindow(onsetTs: ts) }
        default: break
        }
    }
}
