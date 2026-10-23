// PupilAsymmetryV1.swift
// Feature: pupil_asymmetry_v1 (pupillary)
//
// |Left pupil diameter − right pupil diameter| in mm. Uses the same
// dark-pixel ROI segmentation as PupilDiameterBaselineV1 but publishes
// the asymmetry magnitude. Clinical anisocoria threshold is typically
// >0.4 mm under controlled lighting.

import CoreVideo
import Foundation

@MainActor
final class PupilAsymmetryV1: SignalComputer {
    static let signalId: String = "pupil_asymmetry_v1"
    static let sampleKinds: Set<SignalSampleKind> = [.cameraFrame]

    private static let stride: Int = 6
    private var frameCounter: Int = 0
    private static let lumaThreshold: UInt8 = 50
    private static let roiHalfMeters: Float = 0.006

    func reset() { frameCounter = 0 }

    func consume(_ sample: SignalSample, engine: SignalEngine) {
        guard case let .cameraFrame(buf, l, r, fxPx, imgW, imgH, ts) = sample else { return }
        frameCounter += 1
        guard frameCounter % Self.stride == 0 else { return }

        let lMm = l.flatMap { diameterMm(at: $0, buffer: buf, focalPx: fxPx, imgW: imgW, imgH: imgH) }
        let rMm = r.flatMap { diameterMm(at: $0, buffer: buf, focalPx: fxPx, imgW: imgW, imgH: imgH) }
        guard let lv = lMm, let rv = rMm else { return }
        engine.publish(Self.signalId, value: abs(lv - rv), timestamp: ts)
    }

    /// Mirrors PupilDiameterBaselineV1.diameterMm — duplicated rather than
    /// shared so the two computers can evolve independently (e.g., when the
    /// asymmetry uses a CoreML segmenter and the baseline still uses the
    /// dark-pixel heuristic).
    private func diameterMm(at anchor: EyeImageAnchor,
                             buffer: CVPixelBuffer,
                             focalPx: Float,
                             imgW: Int,
                             imgH: Int) -> Double? {
        guard anchor.depthMeters > 0.05, focalPx > 0 else { return nil }
        let roiHalfPx = (Self.roiHalfMeters / anchor.depthMeters) * focalPx
        let roiHalf = max(10, min(200, Int(roiHalfPx.rounded())))
        let cx = Int(anchor.imagePoint.x.rounded())
        let cy = Int(anchor.imagePoint.y.rounded())
        let x0 = max(0, cx - roiHalf)
        let y0 = max(0, cy - roiHalf)
        let x1 = min(imgW - 1, cx + roiHalf)
        let y1 = min(imgH - 1, cy + roiHalf)
        guard x1 > x0, y1 > y0 else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard CVPixelBufferGetPlaneCount(buffer) >= 1,
              let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return nil }
        let stride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        var darkCount = 0
        for y in y0...y1 {
            let rowPtr = ptr.advanced(by: y * stride)
            for x in x0...x1 {
                if rowPtr[x] < Self.lumaThreshold { darkCount += 1 }
            }
        }
        guard darkCount > 4 else { return nil }
        let pixelDiameter = 2.0 * sqrt(Double(darkCount) / .pi)
        let diameterMm = (pixelDiameter / Double(focalPx)) * Double(anchor.depthMeters) * 1000.0
        guard diameterMm >= 1.0, diameterMm <= 12.0 else { return nil }
        return diameterMm
    }
}
