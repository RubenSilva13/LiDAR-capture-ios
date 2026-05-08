import SwiftUI

struct CapturaView: View {
    @StateObject private var vm = CaptureViewModel()
    @State private var modoSelecionado = 0
    let modos = ["Normal", "Alta Res", "ROI Centro"]

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                DepthHeatmapView(depthImage: vm.currentDepthImage)
                    .padding(.horizontal)

                HStack {
                    Text("0.1m").font(.caption).foregroundColor(.blue)
                    LinearGradient(
                        colors: [.blue, .cyan, .green, .yellow, .red],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(height: 8).cornerRadius(4)
                    Text("5m").font(.caption).foregroundColor(.red)
                }
                .padding(.horizontal)

                VStack(spacing: 6) {
                    Text("Modo de Captura").font(.caption).foregroundColor(.secondary)
                    Picker("Modo", selection: $modoSelecionado) {
                        ForEach(0..<modos.count, id: \.self) { i in
                            Text(modos[i]).tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(vm.isCapturing)
                    Text(descricaoModo(modoSelecionado))
                        .font(.caption2).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                VStack(spacing: 4) {
                    Text(vm.status).foregroundColor(.secondary)
                    Text("Frames: \(vm.frameCount)").font(.title2).monospacedDigit()
                }

                Button(vm.isCapturing ? "Parar" : "Iniciar Captura") {
                    vm.captureMode = modoParaEnum(modoSelecionado)
                    vm.toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.isCapturing ? .red : .blue)
                .font(.title3)

                if let url = vm.lastSavedURL {
                    ShareLink(item: url) {
                        Label("Exportar CSV", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Sensor LiDAR")
        }
    }

    private func modoParaEnum(_ idx: Int) -> CaptureMode {
        switch idx {
        case 1: return .highRes
        case 2: return .roi(x: 96, y: 64, width: 64, height: 64)
        default: return .normal
        }
    }

    private func descricaoModo(_ idx: Int) -> String {
        switch idx {
        case 0: return "step=4 · ~3.000 pts/frame · uso geral"
        case 1: return "step=2 · ~12.000 pts/frame · mais detalhe"
        case 2: return "step=1 · região central 64×64px · máximo detalhe"
        default: return ""
        }
    }
}
