import SwiftUI
import ARKit
import SceneKit
import simd

struct ARScannerBoxView: UIViewRepresentable {
    let session: ARSession
    let boxCenter: simd_float3?
    let boxSize: Float

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session = session
        view.scene = SCNScene()
        view.automaticallyUpdatesLighting = true
        view.autoenablesDefaultLighting = true

        view.scene.rootNode.addChildNode(context.coordinator.boxNode)

        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {
        context.coordinator.updateBox(center: boxCenter, size: boxSize)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        let boxNode = SCNNode()

        init() {
            boxNode.isHidden = true
        }

        func updateBox(center: simd_float3?, size: Float) {
            guard let center = center else {
                boxNode.isHidden = true
                boxNode.geometry = nil
                return
            }

            boxNode.isHidden = false
            boxNode.position = SCNVector3(center.x, center.y, center.z)

            let box = SCNBox(
                width: CGFloat(size),
                height: CGFloat(size),
                length: CGFloat(size),
                chamferRadius: 0
            )

            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.25)
            material.emission.contents = UIColor.systemGreen.withAlphaComponent(0.25)
            material.lightingModel = .constant
            material.isDoubleSided = true

            box.materials = [material]
            boxNode.geometry = box
        }
    }
}
