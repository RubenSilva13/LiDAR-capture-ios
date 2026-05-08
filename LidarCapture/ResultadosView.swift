import SwiftUI

struct ResultadosView: View {
    @State private var ficheiros: [URL] = []

    var body: some View {
        NavigationView {
            Group {
                if ficheiros.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 50)).foregroundColor(.secondary)
                        Text("Sem capturas guardadas").font(.title3).foregroundColor(.secondary)
                        Text("Faz uma captura na aba Captura para ver os resultados aqui.")
                            .font(.caption).foregroundColor(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                } else {
                    List(ficheiros, id: \.self) { url in
                        HStack {
                            Image(systemName: "doc.text").foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(url.lastPathComponent).font(.caption).bold()
                                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                                   let size = attrs[.size] as? Int64,
                                   let date = attrs[.modificationDate] as? Date {
                                    Text("\(size / 1024) KB — \(date.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Resultados")
            .onAppear { carregarFicheiros() }
        }
    }

    private func carregarFicheiros() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        ficheiros = (try? FileManager.default.contentsOfDirectory(
            at: docs, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "csv" }.sorted {
            $0.lastPathComponent > $1.lastPathComponent
        }) ?? []
    }
}
