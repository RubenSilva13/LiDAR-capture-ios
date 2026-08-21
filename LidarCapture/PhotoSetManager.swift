import Foundation
import UIKit
import ARKit
import CoreImage
import simd

struct PhotoSetMetadata: Codable {
    let setName: String
    let createdAt: String
    let boxCenter: [Float]?
    let boxSize: Float?
    let photoCount: Int
    let photos: [PhotoMetadata]
}

struct PhotoMetadata: Codable {
    let fileName: String
    let timestamp: TimeInterval
    let cameraTransform: [Float]
    let intrinsics: [Float]
    let imageResolution: [Int]
}

final class PhotoSetManager {

    private let ciContext = CIContext()

    private(set) var sessionURL: URL?
    private var photos: [PhotoMetadata] = []
    private var setName: String = ""

    func startNewSet() throws -> URL {
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let rootFolder = documents.appendingPathComponent("PHOTO_SETS")

        try? FileManager.default.createDirectory(
            at: rootFolder,
            withIntermediateDirectories: true
        )

        setName = "photoscan_\(Int(Date().timeIntervalSince1970))"
        let folderURL = rootFolder.appendingPathComponent(setName)

        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )

        photos = []
        sessionURL = folderURL

        print("Photo set criado:", folderURL)

        return folderURL
    }

    func savePhoto(
        from frame: ARFrame,
        boxCenter: simd_float3?,
        boxSize: Float?
    ) throws -> URL {
        let folderURL: URL

        if let existing = sessionURL {
            folderURL = existing
        } else {
            folderURL = try startNewSet()
        }

        let index = photos.count + 1
        let fileName = String(format: "image_%04d.jpg", index)
        let fileURL = folderURL.appendingPathComponent(fileName)

        guard let jpegData = jpegData(from: frame.capturedImage) else {
            throw NSError(
                domain: "photo.set",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Erro ao converter frame para JPEG."]
            )
        }

        try jpegData.write(to: fileURL)

        let metadata = PhotoMetadata(
            fileName: fileName,
            timestamp: frame.timestamp,
            cameraTransform: matrixToArray(frame.camera.transform),
            intrinsics: intrinsicsToArray(frame.camera.intrinsics),
            imageResolution: [
                Int(frame.camera.imageResolution.width),
                Int(frame.camera.imageResolution.height)
            ]
        )

        photos.append(metadata)

        try saveMetadata(
            boxCenter: boxCenter,
            boxSize: boxSize
        )

        print("Foto guardada:", fileURL)

        return fileURL
    }

    func finish(
        boxCenter: simd_float3?,
        boxSize: Float?
    ) throws -> URL {
        guard let folderURL = sessionURL else {
            throw NSError(
                domain: "photo.set",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Nenhum photo set ativo."]
            )
        }

        try saveMetadata(
            boxCenter: boxCenter,
            boxSize: boxSize
        )

        print("Photo set finalizado:", folderURL)
        return folderURL
    }

    private func saveMetadata(
        boxCenter: simd_float3?,
        boxSize: Float?
    ) throws {
        guard let folderURL = sessionURL else { return }

        let formatter = ISO8601DateFormatter()

        let metadata = PhotoSetMetadata(
            setName: setName,
            createdAt: formatter.string(from: Date()),
            boxCenter: boxCenter.map { [$0.x, $0.y, $0.z] },
            boxSize: boxSize,
            photoCount: photos.count,
            photos: photos
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(metadata)
        let url = folderURL.appendingPathComponent("metadata.json")

        try data.write(to: url)
    }

    private func jpegData(from pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        guard let cgImage = ciContext.createCGImage(
            ciImage,
            from: ciImage.extent
        ) else {
            return nil
        }

        let image = UIImage(
            cgImage: cgImage,
            scale: 1.0,
            orientation: .right
        )

        return image.jpegData(compressionQuality: 0.92)
    }

    private func matrixToArray(_ matrix: simd_float4x4) -> [Float] {
        return [
            matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w,
            matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w,
            matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w,
            matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w
        ]
    }

    private func intrinsicsToArray(_ matrix: simd_float3x3) -> [Float] {
        return [
            matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z,
            matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z,
            matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z
        ]
    }
}
