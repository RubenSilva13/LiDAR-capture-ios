import ARKit
enum CaptureMode {
    case normal        // step=4, frame completo (~3000 pts/frame)
    case highRes       // step=2, frame completo (~12000 pts/frame)
    case roi(x: Int, y: Int, width: Int, height: Int)  // step=1, só numa região
}
class LiDARCaptureSession: NSObject, ARSessionDelegate {
    
    let session = ARSession()
    var onFrameCaptured: (() -> Void)?
    var onDepthFrameReady: ((CVPixelBuffer) -> Void)?
    
    // Modo de captura
    var captureMode: CaptureMode = .normal
    
    private var accumulatedRows: [String] = []
    private let maxRows = 100_000
    
    func start() {
        accumulatedRows = []
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            print("ERRO: Este dispositivo não suporta sceneDepth")
            return
        }
        let config = ARWorldTrackingConfiguration()
        config.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        session.delegate = self
        session.run(config)
    }
    
    func stop() -> URL? {
        session.pause()
        return saveAllToCSV()
    }
    
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depthData = frame.sceneDepth else { return }
        onDepthFrameReady?(depthData.depthMap)
        processFrame(frame: frame,
                     depthMap: depthData.depthMap,
                     confidenceMap: depthData.confidenceMap,
                     timestamp: frame.timestamp)
        onFrameCaptured?()
    }
    
    // Processar frame
    private func processFrame(frame: ARFrame,
                              depthMap: CVPixelBuffer,
                              confidenceMap: CVPixelBuffer?,
                              timestamp: TimeInterval) {
        guard accumulatedRows.count < maxRows else { return }
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width  = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let depthPtr = CVPixelBufferGetBaseAddress(depthMap)!
                           .assumingMemoryBound(to: Float.self)
        
        var confPtr: UnsafeMutablePointer<UInt8>? = nil
        if let cm = confidenceMap {
            CVPixelBufferLockBaseAddress(cm, .readOnly)
            confPtr = CVPixelBufferGetBaseAddress(cm)!
                          .assumingMemoryBound(to: UInt8.self)
        }
        defer {
            if let cm = confidenceMap {
                CVPixelBufferUnlockBaseAddress(cm, .readOnly)
            }
        }
        
        let intrinsics = frame.camera.intrinsics
        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]
        let cx = intrinsics[2][0]
        let cy = intrinsics[2][1]
        
        
        let step: Int
        let xStart, xEnd, yStart, yEnd: Int
        
        switch captureMode {
        case .normal:
            step = 4
            xStart = 0; xEnd = width
            yStart = 0; yEnd = height
            
        case .highRes:
            step = 2
            xStart = 0; xEnd = width
            yStart = 0; yEnd = height
            
        case .roi(let rx, let ry, let rw, let rh):
            step = 1
            xStart = max(0, rx); xEnd = min(width, rx + rw)
            yStart = max(0, ry); yEnd = min(height, ry + rh)
        }
        
        for y in stride(from: yStart, to: yEnd, by: step) {
            for x in stride(from: xStart, to: xEnd, by: step) {
                let index = y * width + x
                let depth = depthPtr[index]
                let confidence = confPtr?[index] ?? 2
                guard depth > 0.1 && depth < 5.0 else { continue }
                
                let worldX = (Float(x) - cx) * depth / fx
                let worldY = (Float(y) - cy) * depth / fy
                let worldZ = depth
                
                accumulatedRows.append(
                    "\(String(format: "%.4f", timestamp))," +
                    "\(x),\(y)," +
                    "\(String(format: "%.4f", depth))," +
                    "\(confidence)," +
                    "\(String(format: "%.4f", worldX))," +
                    "\(String(format: "%.4f", worldY))," +
                    "\(String(format: "%.4f", worldZ))"
                )
            }
        }
    }
    
    
    private func saveAllToCSV() -> URL? {
        guard !accumulatedRows.isEmpty else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        
        
        let modeName: String
        switch captureMode {
        case .normal:   modeName = "normal"
        case .highRes:  modeName = "highres"
        case .roi:      modeName = "roi"
        }
        
        let name = "lidar_\(formatter.string(from: Date()))_\(modeName).csv"
        let file = docs.appendingPathComponent(name)
        let header = "timestamp,x,y,depth_m,confidence,world_x,world_y,world_z\n"
        let content = header + accumulatedRows.joined(separator: "\n")
        do {
            try content.write(to: file, atomically: true, encoding: .utf8)
            print("CSV guardado: \(name) — \(accumulatedRows.count) pontos")
            return file
        } catch {
            print("Erro ao guardar: \(error)")
            return nil
        }
    }
}
