import ARKit
import simd
 
enum CaptureMode {
    case normal
    case highRes
    case roi(x: Int, y: Int, width: Int, height: Int)
}
 
class LiDARCaptureSession: NSObject, ARSessionDelegate {
 
    let session = ARSession()
 
    // Fila dedicada para TODO o trabalho do delegate AR.
    // Mantém a main thread livre → o ARKit nunca deixa de entregar frames
    // e a UI não congela.
    private let sessionQueue = DispatchQueue(label: "com.lidar.sessionQueue")
 
    var onFrameCaptured: (() -> Void)?
    var onDepthFrameReady: ((CVPixelBuffer) -> Void)?
    var onDepthStatsReady: ((Float, Float, Float) -> Void)?
    var onNewPoints: (([simd_float3], [simd_float3]) -> Void)?
 
    // Configuração — definida na main thread antes de start(), lida na sessionQueue.
    var objectBoxCenter: simd_float3? = nil
    var objectBoxSize: Float = 0.25
    var filterByBox = false
    var captureMode: CaptureMode = .normal
    var frameSkip = 0
 
    // Estado partilhado — só tocado dentro da sessionQueue.
    private var frameSkipCounter = 0
    private var accumulatedRows: [String] = []
    private let maxRows = 5_000_000
    private var captureStartTime: TimeInterval = 0
    private let maxDuration: TimeInterval = Double.infinity
    private var isRecording = false
    private var storedMeshAnchors: [UUID: ARMeshAnchor] = [:]
 
    // Lido na main thread (export) — protegido pela fila serial.
    var currentMeshAnchors: [ARMeshAnchor] {
        sessionQueue.sync { Array(storedMeshAnchors.values) }
    }
 
    func startPreview() {
        let config = ARWorldTrackingConfiguration()
 
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        }
 
        session.delegate = self
        // CHAVE: callbacks do delegate fora da main thread.
        session.delegateQueue = sessionQueue
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
 
    func start() {
        sessionQueue.async {
            self.accumulatedRows = []
            self.captureStartTime = Date().timeIntervalSince1970
            self.frameSkipCounter = 0
            self.isRecording = true
        }
    }
 
    func stop() -> URL? {
        var url: URL? = nil
        sessionQueue.sync {
            self.isRecording = false
            url = self.saveAllToCSV()
        }
        return url
    }
 
    func resetMesh() {
        objectBoxCenter = nil
        sessionQueue.async {
            self.accumulatedRows = []
            self.storedMeshAnchors.removeAll()
        }
        guard let config = session.configuration else { return }
        session.run(config, options: [.resetSceneReconstruction, .removeExistingAnchors])
    }
 
    // ── Anchors (chamados na sessionQueue) ─────────────────────────
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let mesh = anchor as? ARMeshAnchor {
                storedMeshAnchors[mesh.identifier] = mesh
            }
        }
    }
 
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let mesh = anchor as? ARMeshAnchor {
                storedMeshAnchors[mesh.identifier] = mesh
            }
        }
    }
 
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if anchor is ARMeshAnchor {
                storedMeshAnchors.removeValue(forKey: anchor.identifier)
            }
        }
    }
 
    // ── Frames (chamados na sessionQueue) ──────────────────────────
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depthData = frame.sceneDepth ?? frame.smoothedSceneDepth else { return }
 
        CVPixelBufferLockBaseAddress(depthData.depthMap, .readOnly)
        let w = CVPixelBufferGetWidth(depthData.depthMap)
        let h = CVPixelBufferGetHeight(depthData.depthMap)
        let ptr = CVPixelBufferGetBaseAddress(depthData.depthMap)!
            .assumingMemoryBound(to: Float.self)
 
        let centerVal = ptr[(h / 2) * w + (w / 2)]
 
        var minVal: Float = 999
        var maxVal: Float = 0
        for i in stride(from: 0, to: w * h, by: 8) {
            let v = ptr[i]
            if v > 0.1 && v < 5.0 {
                minVal = min(minVal, v)
                maxVal = max(maxVal, v)
            }
        }
 
        CVPixelBufferUnlockBaseAddress(depthData.depthMap, .readOnly)
 
        if centerVal > 0.1 && centerVal < 5.0 {
            onDepthStatsReady?(centerVal, minVal, maxVal)
        }
 
        guard isRecording else { return }
 
        if frameSkip > 0 {
            frameSkipCounter += 1
            if frameSkipCounter % (frameSkip + 1) != 0 {
                onFrameCaptured?()
                return
            }
        }
 
        processFrame(
            frame: frame,
            depthMap: depthData.depthMap,
            confidenceMap: depthData.confidenceMap,
            timestamp: frame.timestamp
        )
 
        onFrameCaptured?()
    }
 
    func setObjectBoxCenterFromCurrentFrame() {
        guard let frame = session.currentFrame,
              let depthData = frame.sceneDepth ?? frame.smoothedSceneDepth else {
            print("Sem frame/depth")
            return
        }
 
        let depthMap = depthData.depthMap
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
 
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let depthPtr = CVPixelBufferGetBaseAddress(depthMap)!
            .assumingMemoryBound(to: Float.self)
 
        let x = width / 2
        let y = height / 2
        let depth = depthPtr[y * width + x]
 
        guard depth > 0.1 && depth < 5.0 else {
            print("Depth inválido: \(depth)")
            return
        }
 
        let forward = simd_float3(
            -frame.camera.transform.columns.2.x,
            -frame.camera.transform.columns.2.y,
            -frame.camera.transform.columns.2.z
        )
        let camPos = simd_float3(
            frame.camera.transform.columns.3.x,
            frame.camera.transform.columns.3.y,
            frame.camera.transform.columns.3.z
        )
        objectBoxCenter = camPos + forward * depth
    }
 
    private func processFrame(
        frame: ARFrame,
        depthMap: CVPixelBuffer,
        confidenceMap: CVPixelBuffer?,
        timestamp: TimeInterval
    ) {
        let elapsed = Date().timeIntervalSince1970 - captureStartTime
        guard accumulatedRows.count < maxRows && elapsed < maxDuration else { return }
 
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
 
        let width = CVPixelBufferGetWidth(depthMap)
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
 
        let refWidth = Float(frame.camera.imageResolution.width)
        let refHeight = Float(frame.camera.imageResolution.height)
        let scaleX = Float(width) / refWidth
        let scaleY = Float(height) / refHeight
        let fxD = fx * scaleX
        let fyD = fy * scaleY
        let cxD = cx * scaleX
        let cyD = cy * scaleY
 
        let step: Int
        let xStart: Int
        let xEnd: Int
        let yStart: Int
        let yEnd: Int
 
        switch captureMode {
        case .normal:
            step = 4; xStart = 0; xEnd = width; yStart = 0; yEnd = height
        case .highRes:
            step = 2; xStart = 0; xEnd = width; yStart = 0; yEnd = height
        case .roi(let rx, let ry, let rw, let rh):
            step = 1
            xStart = max(0, rx); xEnd = min(width, rx + rw)
            yStart = max(0, ry); yEnd = min(height, ry + rh)
        }
 
        let cameraTransform = frame.camera.transform
 
        var framePoints: [simd_float3] = []
        var frameColors: [simd_float3] = []
 
        for y in stride(from: yStart, to: yEnd, by: step) {
            for x in stride(from: xStart, to: xEnd, by: step) {
                let index = y * width + x
                let depth = depthPtr[index]
                let confidence = confPtr?[index] ?? 2
 
                guard depth > 0.1 && depth < 5.0 else { continue }
 
                let camX = (Float(x) - cxD) * depth / fxD
                let camY = (Float(y) - cyD) * depth / fyD
                let camZ = -depth
 
                let camPoint = simd_float4(camX, camY, camZ, 1)
                let worldPoint = cameraTransform * camPoint
                let worldX = worldPoint.x
                let worldY = worldPoint.y
                let worldZ = worldPoint.z
 
                if filterByBox, let center = objectBoxCenter {
                    let half = objectBoxSize / 2.0
                    guard abs(worldX - center.x) <= half &&
                          abs(worldY - center.y) <= half &&
                          abs(worldZ - center.z) <= half else {
                        continue
                    }
                }
 
                accumulatedRows.append(
                    "\(String(format: "%.4f", timestamp))," +
                    "\(x),\(y)," +
                    "\(String(format: "%.4f", depth))," +
                    "\(confidence)," +
                    "\(String(format: "%.4f", worldX))," +
                    "\(String(format: "%.4f", worldY))," +
                    "\(String(format: "%.4f", worldZ))"
                )
 
                let (r, g, b) = depthToColor(depth: depth)
                framePoints.append(simd_float3(worldX, worldY, worldZ))
                frameColors.append(simd_float3(r, g, b))
            }
        }
 
        if !framePoints.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.onNewPoints?(framePoints, frameColors)
            }
        }
    }
 
    private func saveAllToCSV() -> URL? {
        guard !accumulatedRows.isEmpty else { return nil }
 
        let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask)[0]
 
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
 
        let modeName: String
        switch captureMode {
        case .normal:  modeName = "normal"
        case .highRes: modeName = "highres"
        case .roi:     modeName = "roi"
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
 
    private func depthToColor(depth: Float) -> (Float, Float, Float) {
        let normalized = min(max((depth - 0.1) / (5.0 - 0.1), 0), 1)
        let v = Double(normalized)
        let r: Double, g: Double, b: Double
        switch v {
        case 0..<0.25:
            let t = v / 0.25;          r = 0;     g = t;     b = 1
        case 0.25..<0.5:
            let t = (v - 0.25) / 0.25; r = 0;     g = 1;     b = 1 - t
        case 0.5..<0.75:
            let t = (v - 0.5) / 0.25;  r = t;     g = 1;     b = 0
        default:
            let t = (v - 0.75) / 0.25; r = 1;     g = 1 - t; b = 0
        }
        return (Float(r), Float(g), Float(b))
    }
}
