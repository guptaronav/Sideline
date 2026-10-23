// GazeDeviationHorizontalV1.swift
// Feature: gaze_deviation_horizontal_v1 (oculomotor)
//
// Horizontal angle (deg) between the left and right eyes' forward
// vectors, projected onto the face's horizontal plane. Positive =
// right eye looks more rightward than left eye (exo-style deviation),
// negative = inward (eso-style). Independent of head pose.
//
// Note: Real strabismus quantification needs a fixation target; without
// one this signal reports the instantaneous binocular alignment, which
// is the right Phase-0 substrate.

import ARKit
import Foundation
import simd

@MainActor
final class GazeDeviationHorizontalV1: SignalComputer {
    static let signalId: String = "gaze_deviation_horizontal_v1"
    static let sampleKinds: Set<SignalSampleKind> = [.faceAnchor]

    func consume(_ sample: SignalSample, engine: SignalEngine) {
        guard case let .faceAnchor(anchor, ts) = sample else { return }
        // Face local X axis (rightward when face is upright):
        let faceX = simd_float3(
            anchor.transform.columns.0.x,
            anchor.transform.columns.0.y,
            anchor.transform.columns.0.z
        )
        let faceY = simd_float3(
            anchor.transform.columns.1.x,
            anchor.transform.columns.1.y,
            anchor.transform.columns.1.z
        )

        // Each eye's forward in face-local space (already normalized by ARKit).
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

        // Project into the face's horizontal plane (drop vertical component).
        // If gaze is purely vertical (eye looking straight up or down,
        // as happens at the .up / .down positions of S11 9-position),
        // the projection is a zero vector and simd_normalize returns
        // NaN. Guard with a small-magnitude floor — if either eye's
        // horizontal projection is too small to define a direction,
        // skip this frame rather than publish NaN.
        let lHraw = lFwd - faceY * simd_dot(lFwd, faceY)
        let rHraw = rFwd - faceY * simd_dot(rFwd, faceY)
        guard simd_length(lHraw) > 1e-4, simd_length(rHraw) > 1e-4 else { return }
        let lH = simd_normalize(lHraw)
        let rH = simd_normalize(rHraw)

        // Signed horizontal angle between the two projected rays.
        let cosTheta = max(-1, min(1, simd_dot(lH, rH)))
        let mag = acosf(cosTheta) * 180 / .pi

        // Sign: positive if right eye points more in +X than left eye.
        let lPx = simd_dot(lH, faceX)
        let rPx = simd_dot(rH, faceX)
        let signed = (rPx >= lPx) ? mag : -mag

        engine.publish(Self.signalId, value: Double(signed), timestamp: ts)
    }
}
