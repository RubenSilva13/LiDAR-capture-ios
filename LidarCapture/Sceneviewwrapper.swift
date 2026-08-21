//
//  SceneViewWrapper.swift
//  LidarCapture
//
//  Visualizador 3D do ficheiro .OBJ exportado
//  Adaptado do projeto cedanmisquith/SwiftUI-LiDAR
//

import SwiftUI
import SceneKit

// ─────────────────────────────────────────────────────────────
// SceneViewWrapper — mostra um ficheiro .OBJ em 3D
// com rotação, zoom e iluminação
// ─────────────────────────────────────────────────────────────
struct SceneViewWrapper: UIViewRepresentable {
    let scene: SCNScene?

    func makeCoordinator() -> Coordinator {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let rootVC = windowScene?.keyWindow?.rootViewController
        return Coordinator(scene: scene, viewController: rootVC)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true        // rotação e zoom com gestos
        scnView.autoenablesDefaultLighting = true
        scnView.antialiasingMode = .multisampling4X
        scnView.backgroundColor = UIColor(white: 0.1, alpha: 1.0)

        // Agrupa todos os nós num nó pai para centrar o modelo
        let parentNode = SCNNode()
        scene?.rootNode.childNodes.forEach { node in
            parentNode.addChildNode(node)
        }
        scene?.rootNode.addChildNode(parentNode)

        // Aplica material cinzento claro ao modelo
        parentNode.enumerateChildNodes { node, _ in
            if let geometry = node.geometry {
                let material = SCNMaterial()
                material.diffuse.contents = UIColor(white: 0.75, alpha: 1.0)
                material.lightingModel = .physicallyBased   // antes: .constant
                material.roughness.contents = 0.9
                material.metalness.contents = 0.0
                material.isDoubleSided = true
                geometry.materials = [material]
            }
        }

        // Centra o modelo
        let (minVec, maxVec) = parentNode.boundingBox
        let dx = (minVec.x + maxVec.x) / 2
        let dy = (minVec.y + maxVec.y) / 2
        let dz = (minVec.z + maxVec.z) / 2
        parentNode.position = SCNVector3(-dx, -dy, -dz)

        // Câmara que encaixa o modelo
        let maxDimension = max(
            maxVec.x - minVec.x,
            maxVec.y - minVec.y,
            maxVec.z - minVec.z
        )
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, maxDimension * 2)
        scene?.rootNode.addChildNode(cameraNode)

        // Luz direcional
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .directional
        lightNode.light?.intensity = 1000
        lightNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene?.rootNode.addChildNode(lightNode)

        // Luz ambiente
        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.color = UIColor(white: 0.3, alpha: 1.0)
        scene?.rootNode.addChildNode(ambientNode)

        scnView.scene = scene
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    class Coordinator: NSObject {
        let scene: SCNScene?
        weak var viewController: UIViewController?

        init(scene: SCNScene?, viewController: UIViewController?) {
            self.scene = scene
            self.viewController = viewController
        }
    }
}

// ─────────────────────────────────────────────────────────────
// Carrega um ficheiro .OBJ da pasta OBJ_FILES
// ─────────────────────────────────────────────────────────────
func loadOBJScene(fileName: String) -> SCNScene? {
    guard let docs = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first else { return nil }

    let url = docs
        .appendingPathComponent("OBJ_FILES")
        .appendingPathComponent(fileName)

    return try? SCNScene(url: url)
}
