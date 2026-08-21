import SwiftUI

struct AnaliseView: View {
    @EnvironmentObject var vm: CaptureViewModel

    @State private var selectedSource: AnalysisSource = .live
    @State private var savedFiles: [SavedCapture] = []
    @State private var fileAnalysis: CSVAnalysis? = nil
    @State private var isAnalyzing = false
    @State private var analysisError: String? = nil

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Fonte de Dados")) {
                    Picker("Ficheiro", selection: $selectedSource) {
                        Text("Sessão atual (ao vivo)").tag(AnalysisSource.live)
                        ForEach(savedFiles) { file in
                            Text(file.name).tag(AnalysisSource.file(file))
                        }
                    }
                    .pickerStyle(.menu)
                }

                switch selectedSource {
                case .live:
                    liveSections
                case .file:
                    fileSections
                }

                Section(header: Text("Sensor LiDAR")) {
                    MetricaRow(icon: "square.grid.2x2", label: "Resolução", valor: "256 × 192 px")
                    MetricaRow(icon: "clock", label: "Frequência", valor: "~30 fps")
                    MetricaRow(icon: "arrow.left.and.right", label: "Alcance válido", valor: "0.1 m — 5.0 m")
                    MetricaRow(icon: "bolt", label: "Tecnologia", valor: "dToF (VCSEL + SPAD)")
                }

                Section(header: Text("Exportação")) {
                    MetricaRow(icon: "doc.text", label: "Formato", valor: "CSV (nuvem) + OBJ (malha)")
                    MetricaRow(icon: "tablecells", label: "Colunas CSV",
                               valor: "timestamp, x, y, depth_m, confidence, world_x, world_y, world_z")
                }
            }
            .navigationTitle("Análise")
            .refreshable { refreshFiles() }
        }
        .onAppear(perform: refreshFiles)
        .task(id: selectedSource) { await loadAnalysisIfNeeded() }
    }

    // MARK: - Secções (sessão ao vivo)

    @ViewBuilder
    private var liveSections: some View {
        Section(header: Text("Métricas Principais")) {
            MetricaRow(icon: "viewfinder", label: "Modo de captura", valor: modoDisplay)
            MetricaRow(icon: "circle.fill", label: "Estado",
                       valor: vm.isCapturing ? "A capturar" : "Parado",
                       corValor: vm.isCapturing ? .green : .secondary)
            MetricaRow(icon: "camera", label: "Frames capturados", valor: "\(vm.frameCount)")
            if vm.scanMode == .objetoFotos {
                MetricaRow(icon: "photo.stack", label: "Fotos capturadas", valor: "\(vm.photoCount)")
            }
            MetricaRow(icon: "scope", label: "Prof. central", valor: formatDepth(vm.centerDepth))
            MetricaRow(icon: "arrow.down.to.line", label: "Prof. mínima", valor: formatDepth(vm.minDepth))
            MetricaRow(icon: "arrow.up.to.line", label: "Prof. máxima", valor: formatDepth(vm.maxDepth))
        }
    }

    // MARK: - Secções (ficheiro guardado)

    @ViewBuilder
    private var fileSections: some View {
        Section(header: Text("Análise do Ficheiro")) {
            if isAnalyzing {
                HStack {
                    ProgressView()
                    Text("A analisar…").foregroundColor(.secondary)
                }
            } else if let erro = analysisError {
                Text(erro).foregroundColor(.secondary).font(.caption)
            } else if let a = fileAnalysis {
                MetricaRow(icon: "number", label: "Pontos totais", valor: "\(a.totalPoints)")
                MetricaRow(icon: "scope", label: "Prof. média", valor: formatDepth(a.meanDepth))
                MetricaRow(icon: "arrow.down.to.line", label: "Prof. mínima", valor: formatDepth(a.minDepth))
                MetricaRow(icon: "arrow.up.to.line", label: "Prof. máxima", valor: formatDepth(a.maxDepth))
                MetricaRow(icon: "waveform.path.ecg", label: "Desvio padrão", valor: formatDepth(a.stdDepth))
            } else {
                Text("Sem dados.").foregroundColor(.secondary).font(.caption)
            }
        }

        if let a = fileAnalysis, !isAnalyzing, analysisError == nil {
            Section(header: Text("Distribuição de Confiança")) {
                MetricaRow(icon: "checkmark.seal", label: "Alta", valor: formatPct(a.highPct), corValor: .green)
                MetricaRow(icon: "seal", label: "Média", valor: formatPct(a.mediumPct), corValor: .orange)
                MetricaRow(icon: "xmark.seal", label: "Baixa", valor: formatPct(a.lowPct), corValor: .red)
            }
        }
    }

    // MARK: - Ações

    private func refreshFiles() {
        savedFiles = listSavedCSVs()
        // Se o ficheiro selecionado já não existir, volta à sessão ao vivo.
        if case let .file(capture) = selectedSource,
           !savedFiles.contains(where: { $0.id == capture.id }) {
            selectedSource = .live
        }
    }

    @MainActor
    private func loadAnalysisIfNeeded() async {
        guard case let .file(capture) = selectedSource else {
            fileAnalysis = nil
            analysisError = nil
            isAnalyzing = false
            return
        }
        isAnalyzing = true
        analysisError = nil
        fileAnalysis = nil
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try analyzeCSV(at: capture.url)
            }.value
            fileAnalysis = result
        } catch {
            analysisError = "Não foi possível analisar este ficheiro."
        }
        isAnalyzing = false
    }

    // MARK: - Helpers

    private var modoDisplay: String {
        switch vm.scanMode {
        case .espaco: return "Espaço"
        case .objeto: return "Objeto"
        case .objetoFotos: return "Objeto + Fotos"
        }
    }

    private func formatDepth(_ value: Float?) -> String {
        guard let value, value > 0, value.isFinite else { return "—" }
        return String(format: "%.2f m", value)
    }

    private func formatPct(_ value: Double) -> String {
        String(format: "%.1f %%", value)
    }
}

struct MetricaRow: View {
    let icon: String
    let label: String
    let valor: String
    var corValor: Color = .secondary

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(valor)
                .foregroundColor(corValor)
                .font(.caption)
                .multilineTextAlignment(.trailing)
        }
    }
}
