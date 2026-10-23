import ARKit
import SceneKit
import SwiftUI

/// The real positioning camera. ARKit owns both the front-camera preview and the
/// 1,220-vertex face geometry, so the wireframe follows the athlete instead of
/// drawing a decorative approximation over a portrait.
struct FaceTrackingCamera: UIViewRepresentable {
    static var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    let meshOpacity: Double

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        view.scene = SCNScene()
        view.backgroundColor = .black
        context.coordinator.meshOpacity = meshOpacity

        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {
        context.coordinator.meshOpacity = meshOpacity
        context.coordinator.faceNode?.opacity = CGFloat(meshOpacity)
    }

    static func dismantleUIView(_ view: ARSCNView, coordinator: Coordinator) {
        view.session.pause()
    }

    final class Coordinator: NSObject, ARSCNViewDelegate {
        var meshOpacity = 1.0
        weak var faceNode: SCNNode?

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard anchor is ARFaceAnchor,
                  let device = renderer.device,
                  let geometry = ARSCNFaceGeometry(device: device)
            else { return nil }

            let material = SCNMaterial()
            material.fillMode = .lines
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.white.withAlphaComponent(0.88)
            material.emission.contents = UIColor.white.withAlphaComponent(0.34)
            material.isDoubleSided = true
            geometry.materials = [material]

            let node = SCNNode(geometry: geometry)
            node.opacity = CGFloat(meshOpacity)
            faceNode = node
            return node
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let geometry = node.geometry as? ARSCNFaceGeometry
            else { return }
            geometry.update(from: faceAnchor.geometry)
            node.opacity = CGFloat(meshOpacity)
        }
    }
}
