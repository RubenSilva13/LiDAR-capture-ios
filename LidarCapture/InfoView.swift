import SwiftUI

struct InfoView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Projeto")) {
                    MetricaRow(icon: "doc.text", label: "Título", valor: "Estudo do Sensor LiDAR iOS")
                    MetricaRow(icon: "building.columns", label: "Instituição", valor: "IPB — ESTIG")
                    MetricaRow(icon: "calendar", label: "Ano letivo", valor: "2025/2026")
                }
                Section(header: Text("Dispositivo")) {
                    MetricaRow(icon: "iphone", label: "Modelo", valor: "iPhone 14 Pro")
                    MetricaRow(icon: "sensor.tag.radiowaves.forward", label: "Sensor LiDAR", valor: "Ativo")
                    MetricaRow(icon: "arrow.left.and.right", label: "Alcance máx.", valor: "5.0 m")
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
                        Text("Usa o ARKit para aceder ao sensor LiDAR, captura dados de profundidade frame a frame com coordenadas 3D reais e exporta-os em CSV para análise em Python.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section(header: Text("Tecnologias")) {
                    Label("Swift / SwiftUI", systemImage: "swift")
                    Label("ARKit", systemImage: "arkit")
                    Label("Python (análise)", systemImage: "desktopcomputer")
                    Label("Blender (visualização 3D)", systemImage: "cube")
                    Label("Figma (design)", systemImage: "paintbrush")
                }
            }
            .navigationTitle("Informação")
        }
    }
}
