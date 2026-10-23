// SmoothPursuitGainV1.swift
// Feature: smooth_pursuit_gain_v1 (oculomotor)
//
// The smooth_pursuit protocol drives a target sinusoidally at 0.4 Hz with
// ±15° amplitude (protocols.json). Pursuit gain = (eye velocity) / (target
// velocity); under a sinusoidal stimulus this is equivalent to the ratio
// of the participant's horizontal-gaze amplitude at 0.4 Hz to the target
// amplitude.
//
// We don't yet have stimulus-position events, so this computer assumes
// the protocol is being run and extracts the 0.4 Hz Fourier component of
// horizontal gaze across a 10-second rolling window. When the participant
// IS doing pursuit, the published value is a real gain estimate; when
// they aren't, the value is ~0 (no oscillation at the protocol frequency).
// That's an honest "live but only meaningful during the protocol"
// behavior — same shape as the rolling velocity in SaccadePeakVelocityV1.

import ARKit
import Foundation
import simd

@MainActor
final class SmoothPursuitGainV1: SignalComputer {
    static let signalId: String = "smooth_pursuit_gain_v1"
    static let sampleKinds: Set<SignalSampleKind> = [.faceAnchor]

    /// Parameters of the smooth_pursuit protocol — kept in sync with
    /// protocols.json. If the protocol changes, update both.
    private let targetFrequencyHz: Double = 0.4
    /// Visual angle of the dot's sweep. The protocol assumes ±15°; Sideline's runner sets the angle the
    /// dot actually subtends on this phone at the measured face distance (about ±5° at 30 cm).
    static var targetAmplitudeDeg: Double = 15.0
    private var targetAmplitudeDeg: Double { Self.targetAmplitudeDeg }

    /// Rolling window over which the Fourier coefficient is estimated.
    /// 10 s == 4 full cycles at 0.4 Hz — the protocol's prescribed dwell.
    private let windowSeconds: Double = 10.0
    /// Don't publish until we have at least 4 s of samples (≈ 1.6 cycles)
    /// so the estimate isn't dominated by edge effects.
    private let minBufferSeconds: Double = 4.0
    /// At 60 Hz face anchors, publish at 2 Hz so the sparkline updates
    /// visibly without thrashing the engine debounce.
    private let publishEvery: Int = 30

    private struct Sample { let t: Double; let azimuthDeg: Double }
    private var buffer: [Sample] = []
    private var sampleCounter: Int = 0

    func reset() {
        buffer.removeAll(keepingCapacity: true)
        sampleCounter = 0
    }

    func consume(_ sample: SignalSample, engine: SignalEngine) {
        guard case let .faceAnchor(anchor, ts) = sample else { return }

        // Mean-eye forward vector → horizontal azimuth (deg).
        // ARKit's eye-transform z column points OUT of the eye, so the
        // forward direction is -z; pursuit motion is mostly in x.
        let lFwd = -simd_float3(
            anchor.leftEyeTransform.columns.2.x,
            anchor.leftEyeTransform.columns.2.y,
            anchor.leftEyeTransform.columns.2.z
        )
        let rFwd = -simd_float3(
            anchor.rightEyeTransform.columns.2.x,
            anchor.rightEyeTransform.columns.2.y,
            anchor.rightEyeTransform.columns.2.z
        )
        let mean = simd_normalize((lFwd + rFwd) * 0.5)
        let azimuthRad = atan2f(mean.x, -mean.z)
        let azimuthDeg = Double(azimuthRad) * 180.0 / .pi

        buffer.append(Sample(t: ts, azimuthDeg: azimuthDeg))
        // Trim to window.
        let cutoff = ts - windowSeconds
        while let first = buffer.first, first.t < cutoff {
            buffer.removeFirst()
        }

        sampleCounter += 1
        guard sampleCounter % publishEvery == 0 else { return }
        guard let firstT = buffer.first?.t, ts - firstT >= minBufferSeconds else { return }

        // Sinusoid fit at known frequency via Fourier coefficients.
        // Mean-subtract first so DC offset (head not exactly forward)
        // doesn't bias the amplitude estimate.
        let n = Double(buffer.count)
        let dcOffset = buffer.reduce(0.0) { $0 + $1.azimuthDeg } / n
        var sumCos = 0.0, sumSin = 0.0
        for s in buffer {
            let x = s.azimuthDeg - dcOffset
            // Window-relative time: ARFrame.timestamp is seconds-since-
            // boot (10^4–10^5 s). At 0.4 Hz target, absolute t produces
            // cos arguments in the 10^5 rad range, where floating-point
            // precision loss makes the value nearly random and the
            // Fourier amplitude estimate collapses to noise. Subtract
            // firstT so phase wraps cleanly across the window.
            let phase = 2.0 * .pi * targetFrequencyHz * (s.t - firstT)
            sumCos += x * cos(phase)
            sumSin += x * sin(phase)
        }
        let a = 2.0 * sumCos / n
        let b = 2.0 * sumSin / n
        let amplitudeDeg = (a * a + b * b).squareRoot()
        let gain = amplitudeDeg / targetAmplitudeDeg

        // Clamp to [0, 1.5] — values > 1 happen with measurement noise +
        // residual head motion; > 1.5 is almost certainly garbage.
        let clamped = max(0.0, min(1.5, gain))
        engine.publish(Self.signalId, value: clamped, timestamp: ts)
    }
}
