// ARKitCapture.swift
// Ported from OculoSense (apps/sensors-testing/OculoSense/Tests/S02_ARKit/ARKitCapture.swift).
// Front TrueDepth face tracking (ARFaceTrackingConfiguration) at 60 Hz. Each tracked frame's face
// anchor goes to the signal engine; when `emitCameraFrames` is on, the captured image goes too,
// with each eye's pupil projected into it, for the pupil computers.
// Dropped from the original: CSV artifacts, the still-image grab and light-estimate publishing.

import ARKit
import Combine
import Foundation
import simd

@MainActor
final class ARKitCapture: NSObject, ObservableObject {

    struct State {
        var isRunning = false
        var error: String?
        var frameCount = 0
        var trackedFrames = 0
        /// Whether the face was tracked on the latest frame.
        var isTracked = false
        var trackedPercent: Double { frameCount == 0 ? 0 : Double(trackedFrames) / Double(frameCount) * 100 }
    }

    nonisolated static var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    /// The session, so a preview view can draw the camera feed and flash over it.
    var previewSession: ARSession { arSession }

    @Published var state = State()

    /// Also send camera frames (with projected eye anchors) to the engine. Pupil computers need these.
    nonisolated(unsafe) var emitCameraFrames = false

    // ARSession is thread-safe; its delegate fires on a background queue.
    nonisolated(unsafe) private let arSession = ARSession()

    override init() {
        super.init()
        arSession.delegate = self
    }

    func start() {
        guard Self.isSupported else {
            state.error = "Face tracking needs a front TrueDepth camera."
            return
        }
        state = State()
        let config = ARFaceTrackingConfiguration()
        config.maximumNumberOfTrackedFaces = 1
        config.isLightEstimationEnabled = true
        arSession.run(config, options: [.resetTracking, .removeExistingAnchors])
        state.isRunning = true
    }

    func stop() {
        arSession.pause()
        state.isRunning = false
    }
}

// MARK: - ARSessionDelegate

extension ARKitCapture: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let faceAnchor = frame.anchors.compactMap { $0 as? ARFaceAnchor }.first
        let isTracked = faceAnchor?.isTracked ?? false

        if let face = faceAnchor, isTracked {
            let ts = frame.timestamp
            // The face anchor's translation is the camera-to-face distance (ARKit's face origin is the camera).
            let distance = Double(abs(face.transform.columns.3.z))
            Task { @MainActor in
                SignalEngine.shared.ingest(.faceAnchor(face, timestamp: ts))
                SignalEngine.shared.publish("face_distance_m", value: distance, timestamp: ts)
            }
            if emitCameraFrames {
                let camera = frame.camera
                let imageRes = camera.imageResolution
                let fx = camera.intrinsics[0][0]
                let pixelBuffer = frame.capturedImage
                let anchors = OcularCalibration.eyeAnchors(from: face, camera: camera)
                Task { @MainActor in
                    SignalEngine.shared.ingest(.cameraFrame(
                        rgbBuffer: pixelBuffer,
                        left: anchors.left,
                        right: anchors.right,
                        focalLengthPx: fx,
                        imageWidth: Int(imageRes.width),
                        imageHeight: Int(imageRes.height),
                        timestamp: ts
                    ))
                }
            }
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.state.frameCount += 1
            if isTracked { self.state.trackedFrames += 1 }
            self.state.isTracked = isTracked
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.state.error = "Camera error: \(error.localizedDescription)"
            self?.state.isRunning = false
        }
    }
}
