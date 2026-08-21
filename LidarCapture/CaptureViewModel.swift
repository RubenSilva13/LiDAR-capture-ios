import Foundation
import Combine
import UIKit
import ARKit
import simd

class CaptureViewModel: ObservableObject {
    @Published var isCapturing = false
    @Published var frameCount  = 0
    @Published var status      = "Câmara pronta"
    @Published var lastSavedURL: URL? = nil
    @Published var currentDepthImage: UIImage? = nil
    @Published var centerDepth: Float? = nil
    @Published var minDepth: Float? = nil
    @Published var maxDepth: Float? = nil
    @Published var pointPositions: [simd_float3] = []
    @Published var pointColors: [simd_float3] = []
    @Published var objectBoxCenter: simd_float3? = nil
    @Published var scanMode: ScanMode = .espaco
    @Published var photoCount = 0
    @Published var photoSetURL: URL? = nil
    @Published var objectBoxSize: Float = 0.25 {
        didSet {
            lidar.objectBoxSize = objectBoxSize
        }
    }

    var captureMode: CaptureMode = .normal
    private let photoSetManager = PhotoSetManager()

    private let lidar = LiDARCaptureSession()

    var arSession: ARSession {
        lidar.session
    }

    var meshAnchors: [ARMeshAnchor] {
        lidar.currentMeshAnchors
    }

    private var previewStarted = false

    init() {
        setupCallbacks()
    }

    func startPreview() {
        guard !previewStarted else { return }

        previewStarted = true
        setupCallbacks()
        lidar.startPreview()
        status = "Câmara pronta"
    }

    func toggle() {
        isCapturing ? stop() : start()
    }

    private func start() {
        if scanMode == .objeto && lidar.objectBoxCenter == nil {
            status = "Define o objeto primeiro"
            return
        }

        frameCount = 0
        lastSavedURL = nil
        pointPositions = []
        pointColors = []

        captureMode = scanMode == .espaco ? .normal : .highRes

        lidar.captureMode = captureMode
        lidar.filterByBox = (scanMode == .objeto)
        lidar.frameSkip = (scanMode == .objeto) ? 3 : 0
        

        if scanMode == .espaco {
            lidar.objectBoxCenter = nil
            objectBoxCenter = nil
        }

        lidar.start()
        isCapturing = true
        status = scanMode == .objeto ? "A capturar objeto..." : "A capturar espaço..."
    }

    private func stop() {
        let url = lidar.stop()

        isCapturing = false
        lastSavedURL = url
        status = url != nil ? "Guardado — \(frameCount) frames" : "Parado — sem dados"
    }

    func resetMesh() {
        pointPositions = []
        pointColors = []
        frameCount = 0
        objectBoxCenter = nil
        lidar.resetMesh()
        status = "Câmara pronta"
    }

    func defineObjectBox() {
        lidar.setObjectBoxCenterFromCurrentFrame()

        DispatchQueue.main.async {
            self.objectBoxCenter = self.lidar.objectBoxCenter
            self.objectBoxSize = self.lidar.objectBoxSize
        }
    }
    
    func startPhotoSet() {
        do {
            let url = try photoSetManager.startNewSet()
            photoSetURL = url
            photoCount = 0
            status = "Sessão de fotos criada"
        } catch {
            status = "Erro ao criar sessão de fotos"
            print("Erro startPhotoSet:", error)
        }
    }

    func captureObjectPhoto() {
        guard scanMode == .objetoFotos else { return }

        guard objectBoxCenter != nil else {
            status = "Define o objeto primeiro"
            return
        }

        guard let frame = arSession.currentFrame else {
            status = "Sem frame ARKit disponível"
            return
        }

        do {
            let url = try photoSetManager.savePhoto(
                from: frame,
                boxCenter: objectBoxCenter,
                boxSize: objectBoxSize
            )

            photoCount += 1
            lastSavedURL = url
            status = "Foto \(photoCount) guardada"

        } catch {
            status = "Erro ao guardar foto"
            print("Erro captureObjectPhoto:", error)
        }
    }

    func finishPhotoSet() {
        do {
            let url = try photoSetManager.finish(
                boxCenter: objectBoxCenter,
                boxSize: objectBoxSize
            )

            photoSetURL = url
            status = "Dataset pronto — \(photoCount) fotos"

        } catch {
            status = "Erro ao finalizar dataset"
            print("Erro finishPhotoSet:", error)
        }
    }
    
    
    
    

    private func setupCallbacks() {
        lidar.onFrameCaptured = { [weak self] in
            DispatchQueue.main.async {
                self?.frameCount += 1
            }
        }

        lidar.onDepthStatsReady = { [weak self] center, min, max in
            DispatchQueue.main.async {
                self?.centerDepth = center
                self?.minDepth = min
                self?.maxDepth = max
            }
        }

        lidar.onNewPoints = { [weak self] positions, colors in
            DispatchQueue.main.async {
                guard let self = self else { return }

                let maxPointsPerFrame = 120
                let step = max(positions.count / maxPointsPerFrame, 1)

                let sampledPositions = stride(from: 0, to: positions.count, by: step).map {
                    positions[$0]
                }

                let sampledColors = stride(from: 0, to: colors.count, by: step).map {
                    colors[$0]
                }

                self.pointPositions.append(contentsOf: sampledPositions)
                self.pointColors.append(contentsOf: sampledColors)

                let maxPreviewPoints = 8_000

                if self.pointPositions.count > maxPreviewPoints {
                    let excess = self.pointPositions.count - maxPreviewPoints
                    self.pointPositions.removeFirst(excess)
                    self.pointColors.removeFirst(excess)
                }
            }
        }
    }
}
