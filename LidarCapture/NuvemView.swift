//
//  NuvemView.swift
//  LidarCapture
//
//  Aba de visualização da nuvem de pontos e ficheiros OBJ exportados
//

import SwiftUI
import SceneKit
import simd

// ─────────────────────────────────────────────────────────────
// NuvemView — aba principal
// ─────────────────────────────────────────────────────────────
struct NuvemView: View {
    @EnvironmentObject var vm: CaptureViewModel
    @State private var objFiles: [String] = []
    @State private var selectedFile: String? = nil
    @State private var showViewer = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Preview da nuvem de pontos em tempo real
                ZStack {
                    Color.black
                    if vm.pointPositions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "cube.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue.opacity(0.5))
                            Text("Nuvem de Pontos")
                                .font(.title2).bold()
                                .foregroundColor(.white)
                            Text("Inicia uma captura na aba Captura\npara ver a nuvem aqui.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        MiniPointCloudPreview(points: vm.pointPositions)
                    }

                    // Contador de pontos
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(vm.pointPositions.count) pts")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .padding(8)
                        }
                        Spacer()
                    }
                }
                .frame(height: 200)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 8)

                // Lista de ficheiros OBJ guardados
                List {
                    Section(header: Text("Estatísticas")) {
                        HStack {
                            Label("Pontos preview", systemImage: "circle.grid.3x3")
                            Spacer()
                            Text("\(vm.pointPositions.count)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Label("Estado", systemImage: "circle.fill")
                                .foregroundColor(vm.isCapturing ? .green : .secondary)
                            Spacer()
                            Text(vm.isCapturing ? "A capturar" : "Parado")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Label("Modelos 3D guardados", systemImage: "cube.box")
                            Spacer()
                            Text("\(objFiles.count)")
                                .foregroundColor(.secondary)
                        }
                    }

                    Section(header: Text("Modelos 3D (.OBJ)")) {
                        if objFiles.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "cube.box")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    Text("Sem modelos guardados")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Usa o botão OBJ na aba Captura")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else {
                            ForEach(objFiles, id: \.self) { file in
                                Button {
                                    selectedFile = file
                                    showViewer = true
                                } label: {
                                    HStack {
                                        Image(systemName: "cube.fill")
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading) {
                                            Text(file)
                                                .font(.caption).bold()
                                                .foregroundColor(.primary)
                                            Text(fileSizeString(file))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .onDelete(perform: deleteOBJ)
                        }
                    }

                    Section(header: Text("Exportar para Blender")) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("1. Exporta o CSV após a captura")
                            Text("2. Corre o script csv_to_ply.py no PC")
                            Text("3. Abre o Blender → File → Import → PLY")
                            Text("4. Ou importa o ficheiro .OBJ diretamente")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)

                        if let url = vm.lastSavedURL {
                            ShareLink(item: url) {
                                Label("Exportar CSV", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nuvem de Pontos")
            .onAppear { loadOBJFiles() }
            .navigationDestination(isPresented: $showViewer) {
                if let file = selectedFile,
                   let scene = loadOBJScene(fileName: file) {
                    OBJViewerView(fileName: file, scene: scene)
                }
            }
        }
    }

    private func loadOBJFiles() {
        guard let docs = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return }

        let folder = docs.appendingPathComponent("OBJ_FILES")
        objFiles = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "obj" }
         .sorted { $0.lastPathComponent > $1.lastPathComponent }
         .map { $0.lastPathComponent }) ?? []
    }

    private func deleteOBJ(at offsets: IndexSet) {
        guard let docs = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return }

        let folder = docs.appendingPathComponent("OBJ_FILES")
        for index in offsets {
            let url = folder.appendingPathComponent(objFiles[index])
            try? FileManager.default.removeItem(at: url)
        }
        objFiles.remove(atOffsets: offsets)
    }

    private func fileSizeString(_ fileName: String) -> String {
        guard let docs = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return "" }

        let url = docs.appendingPathComponent("OBJ_FILES")
            .appendingPathComponent(fileName)

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "" }

        return "\(size / 1024) KB"
    }
}

// ─────────────────────────────────────────────────────────────
// OBJViewerView — visualiza um ficheiro .OBJ em 3D
// ─────────────────────────────────────────────────────────────
struct OBJViewerView: View {
    let fileName: String
    let scene: SCNScene

    var body: some View {
        SceneViewWrapper(scene: scene)
            .ignoresSafeArea()
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
    }
}
