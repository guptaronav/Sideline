// ARFacePreview.swift
// Live ARKit camera + face-mesh wireframe overlay.
// Wraps ARSCNView so a SwiftUI view can display whichever ARSession the
// capture object is running. The face mesh is rendered as a cyan
// wireframe — iconic ARKit visualization that confirms tracking is alive.

import ARKit
import SceneKit
import SwiftUI

struct ARFacePreview: UIViewRepresentable {
    let session: ARSession
    /// Opacity of a full-screen white flash overlay rendered as a UIKit subview
    /// above the Metal layer. SwiftUI overlays cannot reliably composite above
    /// ARSCNView's CAMetalLayer due to asynchronous Metal presentation; a UIView
    /// subview added inside makeUIView is always above the Metal content.
    var flashOpacity: Double = 0

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session = session
        view.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        view.scene = SCNScene()
        view.rendersCameraGrain = false
        view.rendersMotionBlur = false
        view.backgroundColor = .black

        let flash = UIView()
        flash.backgroundColor = .white
        flash.alpha = 0
        flash.isUserInteractionEnabled = false
        flash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        flash.frame = view.bounds
        view.addSubview(flash)
        context.coordinator.flashView = flash

        // When this ARSCNView is created against an already-running session,
        // ARSCNView will NOT retroactively call nodeFor: for face anchors
        // that already exist. We have to manually attach a mesh node for
        // any pre-existing face anchor; subsequent updates flow normally
        // via session(_:didUpdate:).
        context.coordinator.attach(to: view, session: session)

        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.flashView?.alpha = CGFloat(flashOpacity)
        if uiView.session !== session {
            uiView.session = session
            context.coordinator.attach(to: uiView, session: session)
        }
    }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        coordinator.detach()
    }

    /// Maintains a manually-managed face-mesh node so it's visible even
    /// when this ARSCNView is created after ARKit already detected the face.
    final class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        weak var flashView: UIView?
        private weak var sceneView: ARSCNView?
        private weak var arSession: ARSession?
        private var faceNode: SCNNode?
        private var faceGeometry: ARSCNFaceGeometry?
        // We must NOT permanently steal session.delegate — capture objects
        // (e.g. ARKitCapture, CombinedCapture) already own it. Instead we
        // poll the session's currentFrame and update the node ourselves.
        private var displayLink: CADisplayLink?

        func attach(to view: ARSCNView, session: ARSession) {
            self.sceneView = view
            self.arSession = session
            ensureFaceNodeIfPossible()
            startDisplayLink()
        }

        func detach() {
            displayLink?.invalidate()
            displayLink = nil
            faceNode?.removeFromParentNode()
            faceNode = nil
            faceGeometry = nil
        }

        private func startDisplayLink() {
            displayLink?.invalidate()
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        @objc private func tick() {
            ensureFaceNodeIfPossible()
            updateFaceNode()
        }

        private func ensureFaceNodeIfPossible() {
            guard faceNode == nil,
                  let view = sceneView,
                  let frame = arSession?.currentFrame,
                  let _ = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first,
                  let device = MTLCreateSystemDefaultDevice(),
                  let geometry = ARSCNFaceGeometry(device: device)
            else { return }
            geometry.firstMaterial?.fillMode = .lines
            geometry.firstMaterial?.diffuse.contents =
                UIColor(red: 0.31, green: 0.83, blue: 0.99, alpha: 1.0)
            geometry.firstMaterial?.lightingModel = .constant
            let node = SCNNode(geometry: geometry)
            view.scene.rootNode.addChildNode(node)
            self.faceNode = node
            self.faceGeometry = geometry
        }

        private func updateFaceNode() {
            guard let faceAnchor = arSession?.currentFrame?
                    .anchors.compactMap({ $0 as? ARFaceAnchor }).first,
                  let node = faceNode,
                  let geometry = faceGeometry
            else { return }
            node.simdTransform = faceAnchor.transform
            geometry.update(from: faceAnchor.geometry)
        }

        // ARSCNViewDelegate.renderer(_:nodeFor:) is intentionally NOT
        // implemented. We had a parallel implementation that returned its
        // own face-geometry node, which raced with ensureFaceNodeIfPossible
        // — both could fire on first face detection, both see faceNode==nil,
        // both create a node. The displayLink path's node would end up
        // stranded at the origin (the visible "ghost mesh") while the
        // ARSCNView-attached node followed the face. Single source of
        // truth: the manual node added to scene.rootNode and positioned
        // by updateFaceNode().
    }
}
