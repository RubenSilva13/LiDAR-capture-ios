import Foundation
import Combine
import UIKit

class CaptureViewModel: ObservableObject {
    @Published var isCapturing = false
    @Published var frameCount  = 0
    @Published var status      = "Pronto para capturar"
    @Published var lastSavedURL: URL? = nil
    @Published var currentDepthImage: UIImage? = nil
    
    var captureMode: CaptureMode = .normal
    private let lidar = LiDARCaptureSession()

    func toggle() {
        isCapturing ? stop() : start()
    }

    private func start() {
        frameCount = 0
        lastSavedURL = nil
        currentDepthImage = nil
        lidar.onFrameCaptured = { [weak self] in
            DispatchQueue.main.async { self?.frameCount += 1 }
        }
        lidar.onDepthFrameReady = { [weak self] pixelBuffer in
            let image = depthBufferToHeatmap(pixelBuffer)
            DispatchQueue.main.async { self?.currentDepthImage = image }
        }
        lidar.captureMode = captureMode
        lidar.start()
        isCapturing = true
        status = "A capturar dados LiDAR..."
    }

    private func stop() {
        let url = lidar.stop()
        isCapturing = false
        lastSavedURL = url
        status = url != nil ? "Guardado — \(frameCount) frames" : "Parado — sem dados"
    }
}
