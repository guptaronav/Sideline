// PupilDiameterBaselineV1.swift
// Feature: pupil_diameter_baseline_v1 (pupillary)
//
// Mean pupil diameter (mm), averaged across L and R. Approach:
//   1. Sensor (S03) pre-projects each pupil's 3D position into the captured
//      RGB image's pixel space and supplies the camera-to-pupil distance.
//   2. We sample the Y (luma) channel of the captured image in a 40-px ROI
//      around each projected pupil point.
//   3. Threshold dark pixels (luma < 50) to estimate the pupil's segmented
//      area; convert to an equivalent-circle pixel diameter.
//   4. Convert pixel diameter to mm using the camera's focal length (px)
//      and the known pupil depth (m):
//          diameter_mm = (pixel_diameter / focal_length_px) * depth_m * 1000
//
// This is an approximation — Phase 1 will replace the dark-pixel threshold
// with a proper CoreML pupil segmentation model. The architecture is what
// matters here: sensor pre-digests geometry, computer does image work,
// engine publishes the result.
//
// Strided to ~10 Hz (every 6th frame) to keep main-actor cost reasonable.
//
// Image processing is now delegated to PupilMeasurement (shared helper).

import CoreVideo
import Foundation

@MainActor
final class PupilDiameterBaselineV1: SignalComputer {
    static let signalId: String = "pupil_diameter_baseline_v1"
    static let sampleKinds: Set<SignalSampleKind> = [.cameraFrame]

    private static let stride: Int = 6
    private var frameCounter: Int = 0

    func reset() { frameCounter = 0 }

    func consume(_ sample: SignalSample, engine: SignalEngine) {
        guard case let .cameraFrame(buf, l, r, fxPx, _, _, ts) = sample else { return }
        frameCounter += 1
        guard frameCounter % Self.stride == 0 else { return }

        let lMm = l.flatMap { PupilMeasurement.diameter(rgb: buf, anchor: $0, focalPx: fxPx)?.mm }
        let rMm = r.flatMap { PupilMeasurement.diameter(rgb: buf, anchor: $0, focalPx: fxPx)?.mm }

        // Publish whichever side(s) we got.
        if let lv = lMm { engine.publish("pupil_diameter_baseline_v1.left",  value: lv, timestamp: ts) }
        if let rv = rMm { engine.publish("pupil_diameter_baseline_v1.right", value: rv, timestamp: ts) }
        switch (lMm, rMm) {
        case let (l?, r?): engine.publish(Self.signalId, value: (l + r) / 2, timestamp: ts)
        case let (l?, _):  engine.publish(Self.signalId, value: l, timestamp: ts)
        case let (_, r?):  engine.publish(Self.signalId, value: r, timestamp: ts)
        default: break
        }
    }
}
