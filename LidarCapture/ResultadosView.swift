import SwiftUI

struct ResultadosView: View {
    @State private var ficheiros: [URL] = []
    @State private var ficheirosARenomear: URL? = nil
    @State private var novoNome: String = ""
    @State private var mostrarAlertaRenomear = false

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
                    List {
                        ForEach(ficheiros, id: \.self) { url in
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
                                // Botão renomear
                                Button {
                                    ficheirosARenomear = url
                                    novoNome = url.deletingPathExtension().lastPathComponent
                                    mostrarAlertaRenomear = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.orange)
                                }
                                .buttonStyle(.borderless)

                                ShareLink(item: url) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                        }
                        .onDelete(perform: apagarFicheiros)
                    }
                }
            }
            .navigationTitle("Resultados")
            .toolbar {
                EditButton()
            }
            .onAppear { carregarFicheiros() }
            .alert("Renomear ficheiro", isPresented: $mostrarAlertaRenomear) {
                TextField("Novo nome", text: $novoNome)
                Button("Renomear") { renomearFicheiro() }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("Introduz o novo nome (sem extensão)")
            }
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

    private func apagarFicheiros(at offsets: IndexSet) {
        for index in offsets {
            let url = ficheiros[index]
            try? FileManager.default.removeItem(at: url)
        }
        ficheiros.remove(atOffsets: offsets)
    }

    private func renomearFicheiro() {
        guard let url = ficheirosARenomear, !novoNome.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let ext = url.pathExtension
        let novoURL = url.deletingLastPathComponent()
            .appendingPathComponent(novoNome.trimmingCharacters(in: .whitespaces))
            .appendingPathExtension(ext)
        do {
            try FileManager.default.moveItem(at: url, to: novoURL)
            carregarFicheiros()
        } catch {
            print("Erro ao renomear: \(error)")
        }
    }
}
