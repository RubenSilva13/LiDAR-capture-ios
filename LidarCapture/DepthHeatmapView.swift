import SwiftUI
import ARKit

struct DepthHeatmapView: View {
    let depthImage: UIImage?

    var body: some View {
        Group {
            if let img = depthImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(12)
                    .rotationEffect(.degrees(90))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.1))
                    .overlay(Text("A aguardar sensor...").foregroundColor(.secondary))
            }
        }
        .frame(maxHeight: 280)
    }
}

func depthBufferToHeatmap(_ pixelBuffer: CVPixelBuffer,
                           minDepth: Float? = nil,
                           maxDepth: Float? = nil) -> UIImage? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    let width  = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let depthPtr = CVPixelBufferGetBaseAddress(pixelBuffer)!
                       .assumingMemoryBound(to: Float.self)

    // Calcular min/max dinâmico se não fornecido
    var actualMin: Float = minDepth ?? 999
    var actualMax: Float = maxDepth ?? 0

    if minDepth == nil || maxDepth == nil {
        for i in 0..<(width * height) {
            let v = depthPtr[i]
            if v > 0.05 && v < 10.0 {
                if v < actualMin { actualMin = v }
                if v > actualMax { actualMax = v }
            }
        }
    }

    // Margem de 10% para não ficar tudo numa cor
    let range = max(actualMax - actualMin, 0.01)
    let low  = actualMin - range * 0.05
    let high = actualMax + range * 0.05

    var pixels = [UInt8](repeating: 0, count: width * height * 4)

    for y in 0..<height {
        for x in 0..<width {
            let index = y * width + x
            let depth = depthPtr[index]
            let normalized = min(max((depth - low) / (high - low), 0), 1)
            let (r, g, b) = heatmapColor(value: normalized)
            let pixelIndex = index * 4
            pixels[pixelIndex]     = r
            pixels[pixelIndex + 1] = g
            pixels[pixelIndex + 2] = b
            pixels[pixelIndex + 3] = 255
        }
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: &pixels,
        width: width, height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let cgImage = context.makeImage() else { return nil }

    return UIImage(cgImage: cgImage)
}

private func heatmapColor(value: Float) -> (UInt8, UInt8, UInt8) {
    let v = Double(value)
    var r, g, b: Double

    switch v {
    case 0..<0.25:
        let t = v / 0.25
        r = 0; g = t; b = 1
    case 0.25..<0.5:
        let t = (v - 0.25) / 0.25
        r = 0; g = 1; b = 1 - t
    case 0.5..<0.75:
        let t = (v - 0.5) / 0.25
        r = t; g = 1; b = 0
    default:
        let t = (v - 0.75) / 0.25
        r = 1; g = 1 - t; b = 0
    }

    return (UInt8(r * 255), UInt8(g * 255), UInt8(b * 255))
}
