//
//  MeshExporter.swift
//  LidarCapture
//
//  Exporta a malha 3D reconstruída pelo ARKit para ficheiro .OBJ
//

import ARKit
import MetalKit
import ModelIO
import simd

extension ARMeshGeometry {
    func vertex(at index: UInt32) -> SIMD3<Float> {
        assert(vertices.format == .float3,
               "Expected three floats per vertex.")

        let vertexPointer = vertices.buffer.contents()
            .advanced(by: vertices.offset + vertices.stride * Int(index))

        return vertexPointer
            .assumingMemoryBound(to: SIMD3<Float>.self)
            .pointee
    }

    func toMDLMeshSafe(device: MTLDevice,
                       modelMatrix: simd_float4x4) -> MDLMesh {

        let allocator = MTKMeshBufferAllocator(device: device)

        // Copia os vértices para um buffer novo em world space.
        // Não mexe no buffer original do ARKit.
        var vertexFloats: [Float] = []
        vertexFloats.reserveCapacity(vertices.count * 3)

        for i in 0..<vertices.count {
            let localVertex = vertex(at: UInt32(i))
            let world = modelMatrix * SIMD4<Float>(
                localVertex.x,
                localVertex.y,
                localVertex.z,
                1.0
            )

            vertexFloats.append(world.x)
            vertexFloats.append(world.y)
            vertexFloats.append(world.z)
        }

        let vertexData = Data(
            bytes: vertexFloats,
            count: vertexFloats.count * MemoryLayout<Float>.size
        )

        let vertexBuffer = allocator.newBuffer(
            with: vertexData,
            type: .vertex
        )

        let indexData = Data(
            bytes: faces.buffer.contents(),
            count: faces.bytesPerIndex * faces.count * faces.indexCountPerPrimitive
        )

        let indexBuffer = allocator.newBuffer(
            with: indexData,
            type: .index
        )

        let indexType: MDLIndexBitDepth = faces.bytesPerIndex == 4 ? .uInt32 : .uInt16

        let submesh = MDLSubmesh(
            indexBuffer: indexBuffer,
            indexCount: faces.count * faces.indexCountPerPrimitive,
            indexType: indexType,
            geometryType: .triangles,
            material: nil
        )

        let vertexDescriptor = MDLVertexDescriptor()

        vertexDescriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0
        )

        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(
            stride: MemoryLayout<Float>.size * 3
        )

        return MDLMesh(
            vertexBuffer: vertexBuffer,
            vertexCount: vertices.count,
            descriptor: vertexDescriptor,
            submeshes: [submesh]
        )
    }
}

class MeshExporter: NSObject {

    // Método estilo GitHub: ARMeshAnchor -> MDLAsset
    func convertToAsset(meshAnchors: [ARMeshAnchor],
                        camera: ARCamera) -> MDLAsset? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }

        let asset = MDLAsset()

        for anchor in meshAnchors {
            let mesh = anchor.geometry.toMDLMeshSafe(
                device: device,
                modelMatrix: anchor.transform
            )

            asset.add(mesh)
        }

        return asset
    }

    // Exporta o MDLAsset como OBJ
    func exportOBJ(asset: MDLAsset,
                   fileName: String) throws -> URL {
        let directory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let folderURL = directory.appendingPathComponent("OBJ_FILES")

        try? FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )

        let cleanName = fileName.isEmpty
            ? "scan_\(Int(Date().timeIntervalSince1970))"
            : fileName.replacingOccurrences(of: "/", with: "_")

        let url = folderURL.appendingPathComponent("\(cleanName).obj")

        try asset.export(to: url)

        print("OBJ via MDLAsset guardado: \(url)")

        return url
    }

    // Mantemos o exportador manual como fallback/debug.
    func exportOBJFull(meshAnchors: [ARMeshAnchor],
                       fileName: String) throws -> URL {

        var objVertices: [SIMD3<Float>] = []
        var objFaces: [(Int, Int, Int)] = []

        for anchor in meshAnchors {
            let geometry = anchor.geometry
            let transform = anchor.transform
            let baseIndex = objVertices.count

            for i in 0..<geometry.vertices.count {
                let v = geometry.vertex(at: UInt32(i))
                let world = transform * SIMD4<Float>(v.x, v.y, v.z, 1.0)
                objVertices.append(SIMD3<Float>(world.x, world.y, world.z))
            }

            let indexPointer = geometry.faces.buffer.contents()
            let bytesPerIndex = geometry.faces.bytesPerIndex
            let indicesPerFace = geometry.faces.indexCountPerPrimitive

            for faceIndex in 0..<geometry.faces.count {
                guard indicesPerFace == 3 else { continue }

                var idx = [Int](repeating: 0, count: 3)

                for j in 0..<3 {
                    let offset = (faceIndex * indicesPerFace + j) * bytesPerIndex

                    if bytesPerIndex == 4 {
                        idx[j] = Int(indexPointer.load(fromByteOffset: offset, as: UInt32.self))
                    } else {
                        idx[j] = Int(indexPointer.load(fromByteOffset: offset, as: UInt16.self))
                    }
                }

                objFaces.append((
                    baseIndex + idx[0] + 1,
                    baseIndex + idx[1] + 1,
                    baseIndex + idx[2] + 1
                ))
            }
        }

        guard !objFaces.isEmpty else {
            throw NSError(
                domain: "com.lidar.export",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Nenhuma face encontrada na malha."]
            )
        }

        var obj = "# OBJ completo exportado do ARMesh\n"

        for v in objVertices {
            obj += "v \(v.x) \(v.y) \(v.z)\n"
        }

        for face in objFaces {
            obj += "f \(face.0) \(face.1) \(face.2)\n"
        }

        let directory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let folderURL = directory.appendingPathComponent("OBJ_FILES")

        try? FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )

        let cleanName = fileName.isEmpty
            ? "scan_\(Int(Date().timeIntervalSince1970))"
            : fileName.replacingOccurrences(of: "/", with: "_")

        let url = folderURL.appendingPathComponent("\(cleanName).obj")

        try obj.write(to: url, atomically: true, encoding: .utf8)

        print("OBJ manual guardado: \(url)")
        print("Vértices: \(objVertices.count), faces: \(objFaces.count)")

        return url
    }
}
