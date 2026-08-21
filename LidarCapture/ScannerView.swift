//
//  ScannerView.swift
//  LidarCapture
//
//  Ecrã principal de captura com câmara ao vivo,
//  dois modos (Espaço / Objeto), preview da nuvem e exportação OBJ
//

import SwiftUI
import ARKit
import simd

struct ScannerView: View {
    @EnvironmentObject var vm: CaptureViewModel

    @State private var modoEscolhido = false
    @State private var scanProgress: CGFloat = 0.0
    @State private var showResetConfirm = false
    @State private var showExportAlert = false
    @State private var exportFileName = ""
    @State private var showExportSuccess = false
    @State private var exportedFileName = ""

    private let meshExporter = MeshExporter()

    var body: some View {
        if modoEscolhido {
            scannerCamera
        } else {
            modeSelectionScreen
        }
    }

    // ─────────────────────────────────────────────
    // Ecrã de escolha de modo (estilo Kiri)
    // ─────────────────────────────────────────────
    private var modeSelectionScreen: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("Escolhe o modo de captura")
                .font(.title2).bold()

            VStack(spacing: 18) {
                Button {
                    vm.scanMode = .espaco
                    vm.objectBoxCenter = nil
                    modoEscolhido = true
                    vm.startPreview()
                } label: {
                    modeCard(
                        icon: "square.split.bottomrightquarter",
                        title: "Espaço",
                        subtitle: "Quarto, canto, mesa.\nReconstrução de malha 3D (OBJ).",
                        color: .blue
                    )
                }

                Button {
                    vm.scanMode = .objeto
                    modoEscolhido = true
                    vm.startPreview()
                } label: {
                    modeCard(
                        icon: "cube",
                        title: "Objeto",
                        subtitle: "Objeto específico dentro de uma caixa.\nNuvem de pontos densa.",
                        color: .orange
                    )
                }
                Button {
                    vm.scanMode = .objetoFotos
                    vm.objectBoxCenter = nil
                    modoEscolhido = true
                    vm.startPreview()
                    vm.startPhotoSet()
                } label: {
                    modeCard(
                        icon: "camera.viewfinder",
                        title: "Objeto + Fotos",
                        subtitle: "Fotos 360º do objeto.\nDataset para fotogrametria futura.",
                        color: .green
                    )
                }
                
                
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func modeCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundColor(color)
                .frame(width: 60)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3).bold().foregroundColor(.primary)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // ─────────────────────────────────────────────
    // Câmara ao vivo
    // ─────────────────────────────────────────────
    private var scannerCamera: some View {
        ZStack {
            ARScannerBoxView(
                session: vm.arSession,
                boxCenter: (vm.scanMode == .objeto || vm.scanMode == .objetoFotos) ? vm.objectBoxCenter : nil,
                boxSize: vm.objectBoxSize
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Preview da nuvem — só no modo objeto
            if vm.scanMode == .objeto {
                VStack {
                    Spacer()
                    MiniPointCloudPreview(points: vm.pointPositions)
                        .frame(height: 150)
                        .padding(.horizontal)
                        .padding(.bottom, 120)
                }
                .allowsHitTesting(false)
            }

            VStack {
                            scannerTopBar
                            Spacer()
                            scannerCenterGuide
                            Spacer()

                            // Slider de tamanho — só no modo objeto, com caixa definida
                            if vm.scanMode == .objeto && vm.objectBoxCenter != nil {
                                VStack(spacing: 4) {
                                    HStack {
                                        Text("Tamanho da caixa")
                                            .font(.caption).foregroundColor(.white)
                                        Spacer()
                                        Text(String(format: "%.0f cm", vm.objectBoxSize * 100))
                                            .font(.caption).foregroundColor(.white)
                                    }
                                    Slider(value: $vm.objectBoxSize, in: 0.10...0.60)
                                        .tint(.green)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }

                            scannerBottomControls
                        }
                        .padding()

            if showExportSuccess {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("OBJ guardado: \(exportedFileName)")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                    .padding(.bottom, 160)
                }
                .transition(.opacity)
            }
        }
        .onChange(of: vm.frameCount) {
            updateProgress(frameCount: vm.frameCount)
        }
        .onAppear {
            vm.captureMode = vm.scanMode == .espaco ? .normal : .highRes
        }
        .alert("Guardar Modelo 3D", isPresented: $showExportAlert) {
            TextField("Nome do ficheiro", text: $exportFileName)
            Button("Guardar") { exportOBJ() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Introduz o nome para o ficheiro .OBJ")
        }
        .alert("Novo scan?", isPresented: $showResetConfirm) {
            Button("Apagar", role: .destructive) { vm.resetMesh() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Isto limpa a nuvem e a malha atuais.")
        }
    }

    // ─────────────────────────────────────────────
    // Top bar — voltar + novo + estado
    // ─────────────────────────────────────────────
    private var scannerTopBar: some View {
        VStack(spacing: 14) {
            HStack {
                Button("Voltar") {
                    if vm.isCapturing { vm.toggle() }
                    modoEscolhido = false
                }
                .font(.headline)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(18)
                .foregroundColor(.white)

                Button("Novo") {
                    showResetConfirm = true
                }
                .font(.headline)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(18)
                .foregroundColor(.white)

                Spacer()

                Text(
                    vm.scanMode == .espaco ? "Espaço" :
                    vm.scanMode == .objeto ? "Objeto" :
                    "Objeto + Fotos"
                )
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(18)
                    .foregroundColor(.white)
            }

            ProgressView(value: scanProgress)
                .tint(.orange)
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
    }

    // ─────────────────────────────────────────────
    // Centro — guia de scan
    // ─────────────────────────────────────────────
    private var scannerCenterGuide: some View {
        VStack(spacing: 14) {
            if vm.scanMode == .objeto {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 18)
                        .frame(width: 230, height: 230)
                    Circle()
                        .trim(from: 0, to: scanProgress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 230, height: 230)
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.85), lineWidth: 2)
                        .frame(width: 150, height: 150)
                    Circle().fill(Color.white).frame(width: 10, height: 10)
                }
            }

            Text(captionGuia)
                .font(.headline)
                .foregroundColor(.white)
                .shadow(radius: 4)

            if vm.scanMode == .objetoFotos {
                Text("\(vm.photoCount) fotos")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            } else {
                Text("\(vm.pointPositions.count) pontos · \(vm.frameCount) frames")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
    }
    
    

    private var captionGuia: String {
        if vm.scanMode == .espaco {
            return vm.isCapturing ? "Move o telefone pelo espaço" : "Aponte para o espaço"
        } else if vm.scanMode == .objeto {
            return vm.isCapturing ? "Move lentamente à volta do objeto" : "Aponte para o objeto"
        } else {
            return "Tira fotos à volta do objeto"
        }
    }

    // ─────────────────────────────────────────────
    // Bottom — estado + OBJ + definir objeto + captura
    // ─────────────────────────────────────────────
    @ViewBuilder
    private var scannerBottomControls: some View {
        if vm.scanMode == .objetoFotos {
            photoBottomControls
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(vm.status)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))

                    if let dist = vm.centerDepth {
                        Text(String(format: "Dist.: %.2f m", dist))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.75))
                    }
                }

                Spacer()

                // Botão exportar OBJ — só aparece quando não está a capturar
                if !vm.isCapturing && vm.frameCount > 0 {
                    Button {
                        exportFileName = "scan_\(Int(Date().timeIntervalSince1970))"
                        showExportAlert = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "cube.fill")
                                .font(.title2)
                            Text("OBJ")
                                .font(.caption2)
                                .bold()
                        }
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                    .padding(.trailing, 12)
                }

                // Botão "Definir objeto" — só no modo objeto
                if vm.scanMode == .objeto {
                    Button("Definir objeto") {
                        vm.defineObjectBox()
                    }
                    .font(.caption)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
                    .foregroundColor(.white)
                }

                // Botão principal de captura
                Button {
                    vm.captureMode = vm.scanMode == .espaco ? .normal : .highRes
                    vm.toggle()

                    if vm.isCapturing {
                        scanProgress = 0
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(vm.isCapturing ? Color.red : Color.white)
                            .frame(width: 78, height: 78)

                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 4)
                            .frame(width: 90, height: 90)

                        if vm.isCapturing {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white)
                                .frame(width: 26, height: 26)
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    private var photoBottomControls: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(vm.status)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))

                if let dist = vm.centerDepth {
                    Text(String(format: "Dist.: %.2f m", dist))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.75))
                }

                Text("\(vm.photoCount) fotos")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.75))
            }

            Spacer()

            Button("Definir objeto") {
                vm.defineObjectBox()
            }
            .font(.caption)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(14)
            .foregroundColor(.white)

            Button {
                vm.captureObjectPhoto()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 78, height: 78)

                    Image(systemName: "camera.fill")
                        .font(.title)
                        .foregroundColor(.black)

                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 4)
                        .frame(width: 90, height: 90)
                }
            }

            Button("Finalizar") {
                vm.finishPhotoSet()
            }
            .font(.caption)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(14)
            .foregroundColor(.white)
        }
        .padding(.bottom, 20)
    }

    // ─────────────────────────────────────────────
    // Exportar OBJ da malha reconstruída pelo ARKit
    // ─────────────────────────────────────────────
    private func exportOBJ() {
        let meshAnchors = vm.meshAnchors

        print("Mesh anchors guardados:", meshAnchors.count)

        guard !meshAnchors.isEmpty else {
            print("Sem malha 3D disponível — certifica-te que fizeste scan suficiente")
            return
        }

        guard let frame = vm.arSession.currentFrame else {
            print("Sem frame ARKit disponível")
            return
        }

        do {
            guard let asset = meshExporter.convertToAsset(
                meshAnchors: meshAnchors,
                camera: frame.camera
            ) else {
                print("Erro ao converter malha para MDLAsset")
                return
            }

            let url = try meshExporter.exportOBJ(
                asset: asset,
                fileName: exportFileName
            )

            exportedFileName = url.lastPathComponent

            withAnimation {
                showExportSuccess = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showExportSuccess = false
                }
            }

        } catch {
            print("Erro ao exportar OBJ: \(error)")
        }
    }

    private func updateProgress(frameCount: Int) {
        guard vm.isCapturing else { return }
        let targetFrames: CGFloat = 180
        scanProgress = min(CGFloat(frameCount) / targetFrames, 1.0)
    }
}

// ─────────────────────────────────────────────────────────────
// MiniPointCloudPreview — preview 2D top-down dos pontos
// ─────────────────────────────────────────────────────────────
struct MiniPointCloudPreview: View {
    let points: [simd_float3]

    var body: some View {
        Canvas { context, size in
            guard !points.isEmpty else { return }

            let xs = points.map { CGFloat($0.x) }
            let zs = points.map { CGFloat($0.z) }

            guard let minX = xs.min(), let maxX = xs.max(),
                  let minZ = zs.min(), let maxZ = zs.max() else { return }

            let rangeX = max(maxX - minX, 0.01)
            let rangeZ = max(maxZ - minZ, 0.01)

            for p in points {
                let x = (CGFloat(p.x) - minX) / rangeX * size.width
                let y = (CGFloat(p.z) - minZ) / rangeZ * size.height
                let rect = CGRect(x: x, y: y, width: 2, height: 2)
                context.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }
}
