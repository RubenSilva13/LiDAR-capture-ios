import SwiftUI
import UIKit
import ARKit

struct InfoView: View {

    private var iosVersion: String { UIDevice.current.systemVersion }

    private var lidarDisponivel: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Projeto")) {
                    MetricaRow(icon: "doc.text", label: "Título",
                               valor: "Estudo e Modelação Computacional do Sensor LiDAR em Dispositivos iOS")
                    MetricaRow(icon: "building.columns", label: "Instituição", valor: "IPB — ESTIG")
                    MetricaRow(icon: "calendar", label: "Ano letivo", valor: "2025/2026")
                }

                Section(header: Text("Dispositivo")) {
                    MetricaRow(icon: "iphone", label: "Modelo", valor: "iPhone 14 Pro")
                    MetricaRow(icon: "gearshape", label: "Sistema", valor: "iOS \(iosVersion)")
                    MetricaRow(icon: "sensor.tag.radiowaves.forward", label: "Sensor LiDAR",
                               valor: lidarDisponivel ? "Ativo (dToF)" : "Indisponível",
                               corValor: lidarDisponivel ? .green : .red)
                    MetricaRow(icon: "arrow.left.and.right", label: "Alcance válido", valor: "0.1 – 5.0 m")
                }

                Section(header: Text("Modos de Captura")) {
                    ModoRow(icon: "cube.transparent",
                            titulo: "Modo Espaço",
                            descricao: "Reconstrói a malha 3D do ambiente (sceneReconstruction), exportada em OBJ. Grava a nuvem completa, sem filtragem.")
                    ModoRow(icon: "shippingbox",
                            titulo: "Modo Objeto",
                            descricao: "Filtra a nuvem de pontos a uma caixa delimitadora 3D ajustável e grava-a em CSV (alta resolução).")
                    ModoRow(icon: "camera.viewfinder",
                            titulo: "Modo Objeto + Fotos",
                            descricao: "Captura fotos RGB (1920×1440) com pose e intrínsecos da câmara — dataset para fotogrametria externa.")
                }

                Section(header: Text("Sobre o LiDAR")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("O que é o LiDAR?").font(.headline)
                        Text("Light Detection and Ranging — dispara pulsos de luz infravermelha e mede o tempo de retorno para calcular distâncias com precisão de centímetros.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Como funciona esta app?").font(.headline)
                        Text("Usa o ARKit para aceder ao depthMap e confidenceMap do sensor LiDAR, captura dados de profundidade frame a frame com coordenadas 3D reais e exporta-os para análise em Python.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Tecnologias")) {
                    Label("Swift / SwiftUI", systemImage: "swift")
                    Label("ARKit (captura)", systemImage: "arkit")
                    Label("SceneKit (visualização 3D)", systemImage: "rotate.3d")
                    Label("Python (análise / conversão)", systemImage: "chart.bar")
                    Label("CloudCompare / Blender (nuvem de pontos)", systemImage: "cube")
                    Label("Meshroom (fotogrametria — trabalho futuro)", systemImage: "camera.metering.matrix")
                }
            }
            .navigationTitle("Informação")
        }
    }
}

struct ModoRow: View {
    let icon: String
    let titulo: String
    let descricao: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(titulo, systemImage: icon)
                .font(.subheadline.weight(.semibold))
            Text(descricao)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
