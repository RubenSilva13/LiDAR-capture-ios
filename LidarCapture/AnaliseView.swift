import SwiftUI

struct AnaliseView: View {
    @StateObject private var vm = CaptureViewModel()

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Métricas Principais")) {
                    MetricaRow(icon: "camera", label: "Frames capturados", valor: "\(vm.frameCount)")
                    MetricaRow(icon: "circle.fill", label: "Estado",
                               valor: vm.isCapturing ? "A capturar" : "Parado",
                               corValor: vm.isCapturing ? .green : .secondary)
                    MetricaRow(icon: "ruler", label: "Área total", valor: "—")
                    MetricaRow(icon: "arrow.down.to.line", label: "Prof. máxima", valor: "—")
                    MetricaRow(icon: "checkmark.seal", label: "Qualidade", valor: "—")
                }
                Section(header: Text("Sensor LiDAR")) {
                    MetricaRow(icon: "square.grid.2x2", label: "Resolução", valor: "256 × 192 px")
                    MetricaRow(icon: "clock", label: "Frequência", valor: "~30 fps")
                    MetricaRow(icon: "arrow.left.and.right", label: "Alcance", valor: "0.1m — 5.0m")
                    MetricaRow(icon: "square.dotted", label: "Amostragem", valor: "1 em cada 4 px")
                }
                Section(header: Text("Exportação")) {
                    MetricaRow(icon: "doc.text", label: "Formato", valor: "CSV + PLY")
                    MetricaRow(icon: "tablecells", label: "Colunas CSV",
                               valor: "timestamp, x, y, depth, confidence, worldX, worldY, worldZ")
                }
            }
            .navigationTitle("Análise")
        }
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
