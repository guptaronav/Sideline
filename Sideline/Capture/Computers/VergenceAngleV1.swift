// VergenceAngleV1.swift
// Feature: vergence_angle_v1 (oculomotor)
//
// Angle between the two eyes' forward (gaze) vectors in degrees.
// Positive = convergence (eyes turned inward toward a near target),
// negative = divergence. Computed from leftEyeTransform / rightEyeTransform
// forward directions (-Z column of each).

import ARKit
import Foundation
import simd

@MainActor
final class VergenceAngleV1: SignalComputer {
    static let signalId: String = "vergence_angle_v1"
    static let sampleKinds: Set<SignalSampleKind> = [.faceAnchor]

    func consume(_ sample: SignalSample, engine: SignalEngine) {
        guard case let .faceAnchor(anchor, ts) = sample else { return }
        let l = anchor.leftEyeTransform
        let r = anchor.rightEyeTransform
        // Each forward = -Z column.
        let lFwd = simd_normalize(-simd_float3(l.columns.2.x, l.columns.2.y, l.columns.2.z))
        let rFwd = simd_normalize(-simd_float3(r.columns.2.x, r.columns.2.y, r.columns.2.z))
        // Eye positions (origin of each eye in face frame).
        let lPos = simd_float3(l.columns.3.x, l.columns.3.y, l.columns.3.z)
        let rPos = simd_float3(r.columns.3.x, r.columns.3.y, r.columns.3.z)

        let cosTheta = max(-1, min(1, simd_dot(lFwd, rFwd)))
        let baseAngle = acosf(cosTheta) * 180 / .pi // 0..180

        // Sign: convergence if the rays angle toward each other in the
        // baseline direction (i.e., the projection of lFwd onto the
        // baseline axis is opposite to that of rFwd).
        let baselineAxis = simd_normalize(rPos - lPos) // points from L to R
        let lProj = simd_dot(lFwd, baselineAxis)
        let rProj = simd_dot(rFwd, baselineAxis)
        let convergence = (lProj > 0) && (rProj < 0)
        let signedAngle = convergence ? baseAngle : -baseAngle

        engine.publish(Self.signalId, value: Double(signedAngle), timestamp: ts)
    }
}
