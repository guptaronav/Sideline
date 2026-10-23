// SaccadePeakVelocityV1.swift
// Feature: saccade_peak_velocity_v1 (oculomotor)
//
// Angular gaze velocity in deg/s computed from the frame-to-frame
// change in mean-eye forward vector. Saccades show as short bursts
// of high velocity (>100 deg/s).
//
// Published value is the **maximum velocity in a rolling 10-second
// window** — true "peak" semantics matching the signal_id name.
// The previous implementation published the per-frame instantaneous
// velocity, which meant the captured value at the end of any ARKit
// session was whatever the user's gaze was doing in that last frame
// (typically zero — looking steady at the camera). The peak of the
// saccades that DID happen during the capture got overwritten by
// quiescent frames. Same root-cause class as the voice F0 / tremor
// 0-overwrite bug fixed in 9c06d97.

import ARKit
import Foundation
import simd

@MainActor
final class SaccadePeakVelocityV1: SignalComputer {
    static let signalId: String = "saccade_peak_velocity_v1"
    static let sampleKinds: Set<SignalSampleKind> = [.faceAnchor]

    private var lastFwd: SIMD3<Float>?
    private var lastTs: TimeInterval = 0
    private struct VelSample { let t: TimeInterval; let v: Double }
    /// 10-second rolling window of per-frame velocities. The published
    /// value is the max within this window. 10 s is long enough that
    /// any saccade made during a typical 22–30 s capture stays in the
    /// window when finish() reads the last value; short enough that
    /// the peak doesn't persist across captures or warm-up periods.
    private var window: [VelSample] = []
    private static let windowSeconds: TimeInterval = 10.0

    func reset() {
        lastFwd = nil; lastTs = 0
        window.removeAll(keepingCapacity: true)
    }

    func consume(_ sample: SignalSample, engine: SignalEngine) {
        guard case let .faceAnchor(anchor, ts) = sample else { return }
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

        defer { lastFwd = mean; lastTs = ts }
        guard let prev = lastFwd, lastTs > 0 else { return }

        let dt = ts - lastTs
        guard dt > 0 else { return }
        let cosTheta = max(-1, min(1, simd_dot(prev, mean)))
        let dThetaDeg = acosf(cosTheta) * 180 / .pi
        let velDegPerSec = Double(dThetaDeg) / dt

        window.append(VelSample(t: ts, v: velDegPerSec))
        let cutoff = ts - Self.windowSeconds
        while let first = window.first, first.t < cutoff { window.removeFirst() }
        let peak = window.map(\.v).max() ?? velDegPerSec
        engine.publish(Self.signalId, value: peak, timestamp: ts)
    }
}
