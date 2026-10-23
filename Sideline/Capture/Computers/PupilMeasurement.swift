// OculoSense/Common/Signals/Computers/PupilMeasurement.swift
// Pure dark-pixel luma-threshold pupil-diameter helper. Shared between
// PupilDiameterBaselineV1 (live signal) and PupilStreamRecorder (CSV artifact).
// One CV implementation backs both — no duplicated image processing.

import CoreVideo
import Foundation

enum PupilMeasurement {
    /// Dark-pixel threshold matching PupilDiameterBaselineV1.
    private static let lumaThreshold: UInt8 = 50
    /// Physical ROI half-width in metres (6 mm) projected to px each call.
    private static let roiHalfMeters: Float = 0.006

    /// Measure the pupil at `anchor` in the YCbCr `rgb` buffer.
    /// Returns (pixel diameter, mm diameter) or nil when the measurement
    /// is invalid (no face, bad depth, out-of-range mm clamp, tiny dark area).
    ///
    /// mm formula: (pixelDiam / focalPx) * depthMeters * 1000.
    /// Valid range: 1.0–12.0 mm (human pupil physiological bounds).
    static func diameter(rgb: CVPixelBuffer,
                         anchor: EyeImageAnchor,
                         focalPx: Float) -> (px: Double, mm: Double)? {
        guard anchor.depthMeters > 0.05, focalPx > 0 else { return nil }

        let w = CVPixelBufferGetWidth(rgb)
        let h = CVPixelBufferGetHeight(rgb)
        let roiHalfPx = (roiHalfMeters / anchor.depthMeters) * focalPx
        let roiHalf = max(10, min(200, Int(roiHalfPx.rounded())))
        let cx = Int(anchor.imagePoint.x.rounded())
        let cy = Int(anchor.imagePoint.y.rounded())
        let x0 = max(0, cx - roiHalf)
        let y0 = max(0, cy - roiHalf)
        let x1 = min(w - 1, cx + roiHalf)
        let y1 = min(h - 1, cy + roiHalf)
        guard x1 > x0, y1 > y0 else { return nil }

        // ARKit captured image is 420f bi-planar YCbCr. Plane 0 = full-res Y.
        CVPixelBufferLockBaseAddress(rgb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(rgb, .readOnly) }
        guard CVPixelBufferGetPlaneCount(rgb) >= 1,
              let base = CVPixelBufferGetBaseAddressOfPlane(rgb, 0)
        else { return nil }
        let stride = CVPixelBufferGetBytesPerRowOfPlane(rgb, 0)
        let ptr = base.assumingMemoryBound(to: UInt8.self)

        var darkCount = 0
        for y in y0...y1 {
            let row = ptr.advanced(by: y * stride)
            for x in x0...x1 {
                if row[x] < lumaThreshold { darkCount += 1 }
            }
        }
        guard darkCount > 4 else { return nil }

        let pixelDiameter = 2.0 * sqrt(Double(darkCount) / .pi)
        let mm = mmFromPixelDiameter(pixelDiameter, focalPx: focalPx,
                                     depthMeters: anchor.depthMeters)
        guard mm >= 1.0, mm <= 12.0 else { return nil }
        return (px: pixelDiameter, mm: mm)
    }

    /// Convert a pixel-space equivalent-circle diameter to millimetres.
    /// Small-angle approximation valid for 10–30 cm phone-to-face distances.
    /// Exposed at internal access for unit testing.
    static func mmFromPixelDiameter(_ pixelDiameter: Double,
                                    focalPx: Float,
                                    depthMeters: Float) -> Double {
        (pixelDiameter / Double(focalPx)) * Double(depthMeters) * 1000.0
    }
}
