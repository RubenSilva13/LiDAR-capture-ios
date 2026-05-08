import SwiftUI

struct NuvemView: View {
    @StateObject private var vm = CaptureViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "cube.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("Nuvem de Pontos 3D").font(.title2).bold()
                    Text("Captura dados com coordenadas 3D reais (X, Y, Z em metros) para visualização no Blender.")
                        .font(.caption).foregroundColor(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }
                .padding(.top, 40)

                HStack(spacing: 20) {
                    EstatCard(valor: "\(vm.frameCount * 3072)", label: "Pontos")
                    EstatCard(valor: "—", label: "Camadas")
                    EstatCard(valor: "PLY", label: "Formato")
                }

                GroupBox(label: Label("Como visualizar no Blender", systemImage: "info.circle")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. Exporta o CSV após a captura")
                        Text("2. Corre o script csv_to_ply.py no PC")
                        Text("3. Abre o Blender → File → Import → PLY")
                    }
                    .font(.caption).foregroundColor(.secondary).padding(.top, 4)
                }
                .padding(.horizontal)

                if let url = vm.lastSavedURL {
                    ShareLink(item: url) {
                        Label("Exportar dados para PLY", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .navigationTitle("Nuvem de Pontos")
        }
    }
}

struct EstatCard: View {
    let valor: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(valor).font(.title2).bold().foregroundColor(.blue)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(width: 90, height: 70)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
