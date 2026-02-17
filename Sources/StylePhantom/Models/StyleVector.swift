import Foundation
import simd

struct StyleVector: Sendable, Equatable {
    /// 5 dominant RGBA colors extracted from the artifact
    var colorPalette: [SIMD4<Float>]
    /// Rule-of-thirds, symmetry, focal-point, negative-space, depth, layering, balance, flow
    var composition: SIMD8<Float>
    /// Roughness, grain, sharpness, pattern-density
    var texture: SIMD4<Float>
    /// Overall visual complexity 0.0-1.0
    var complexity: Float

    static let dimensionCount = 33 // 20 + 8 + 4 + 1

    static let zero = StyleVector(
        colorPalette: Array(repeating: .zero, count: 5),
        composition: .zero,
        texture: .zero,
        complexity: 0
    )

    /// Flatten all dimensions into a single [Float] array for clustering
    var flattened: [Float] {
        var result: [Float] = []
        result.reserveCapacity(Self.dimensionCount)
        for color in colorPalette {
            result.append(contentsOf: [color.x, color.y, color.z, color.w])
        }
        for i in 0..<8 { result.append(composition[i]) }
        for i in 0..<4 { result.append(texture[i]) }
        result.append(complexity)
        return result
    }

    /// Reconstruct a StyleVector from a flat [Float] array
    static func from(flattened: [Float]) -> StyleVector? {
        guard flattened.count == dimensionCount else { return nil }
        var idx = 0
        var palette: [SIMD4<Float>] = []
        palette.reserveCapacity(5)
        for _ in 0..<5 {
            palette.append(SIMD4(flattened[idx], flattened[idx + 1], flattened[idx + 2], flattened[idx + 3]))
            idx += 4
        }
        let comp = SIMD8<Float>(
            flattened[idx], flattened[idx + 1], flattened[idx + 2], flattened[idx + 3],
            flattened[idx + 4], flattened[idx + 5], flattened[idx + 6], flattened[idx + 7]
        )
        idx += 8
        let tex = SIMD4<Float>(flattened[idx], flattened[idx + 1], flattened[idx + 2], flattened[idx + 3])
        idx += 4
        return StyleVector(colorPalette: palette, composition: comp, texture: tex, complexity: flattened[idx])
    }
}

// MARK: - Codable (SIMD types need custom encoding)

extension StyleVector: Codable {
    enum CodingKeys: String, CodingKey {
        case colorPalette, composition, texture, complexity
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let paletteArrays = colorPalette.map { [$0.x, $0.y, $0.z, $0.w] }
        try container.encode(paletteArrays, forKey: .colorPalette)
        var comp: [Float] = []
        for i in 0..<8 { comp.append(composition[i]) }
        try container.encode(comp, forKey: .composition)
        try container.encode([texture.x, texture.y, texture.z, texture.w], forKey: .texture)
        try container.encode(complexity, forKey: .complexity)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let paletteArrays = try container.decode([[Float]].self, forKey: .colorPalette)
        guard paletteArrays.count == 5 else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [CodingKeys.colorPalette], debugDescription: "Expected 5 palette entries, got \(paletteArrays.count)")
            )
        }
        colorPalette = paletteArrays.map { arr in
            SIMD4(arr.count > 0 ? arr[0] : 0, arr.count > 1 ? arr[1] : 0, arr.count > 2 ? arr[2] : 0, arr.count > 3 ? arr[3] : 1)
        }

        let comp = try container.decode([Float].self, forKey: .composition)
        guard comp.count == 8 else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [CodingKeys.composition], debugDescription: "Expected 8 composition values, got \(comp.count)")
            )
        }
        composition = SIMD8(comp[0], comp[1], comp[2], comp[3], comp[4], comp[5], comp[6], comp[7])

        let tex = try container.decode([Float].self, forKey: .texture)
        guard tex.count == 4 else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [CodingKeys.texture], debugDescription: "Expected 4 texture values, got \(tex.count)")
            )
        }
        texture = SIMD4(tex[0], tex[1], tex[2], tex[3])

        complexity = try container.decode(Float.self, forKey: .complexity)
    }
}

// MARK: - Version-Prefixed Data Encoding

extension StyleVector {
    static let currentVersion: UInt8 = 1

    /// Encode to Data with a leading version byte for safe schema evolution
    func encodeToPrefixedData() -> Data {
        var data = Data([Self.currentVersion])
        if let jsonData = try? JSONEncoder().encode(self) {
            data.append(jsonData)
        }
        return data
    }

    /// Decode from version-prefixed Data, returning nil for unknown versions or corrupted data
    static func decode(from data: Data) -> StyleVector? {
        guard data.count > 1 else { return nil }
        let version = data[data.startIndex]
        guard version == currentVersion else { return nil }
        let jsonData = data[(data.startIndex + 1)...]
        return try? JSONDecoder().decode(StyleVector.self, from: Data(jsonData))
    }
}
