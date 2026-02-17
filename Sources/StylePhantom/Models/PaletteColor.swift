import Foundation
import simd

struct PaletteColor: Codable, Sendable, Equatable, Identifiable {
    var id: String { hex }
    let hex: String
    let name: String
    let rgba: SIMD4<Float>

    enum CodingKeys: String, CodingKey {
        case hex, name, rgba
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hex, forKey: .hex)
        try container.encode(name, forKey: .name)
        try container.encode([rgba.x, rgba.y, rgba.z, rgba.w], forKey: .rgba)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hex = try container.decode(String.self, forKey: .hex)
        name = try container.decode(String.self, forKey: .name)
        let arr = try container.decode([Float].self, forKey: .rgba)
        rgba = SIMD4(arr.count > 0 ? arr[0] : 0, arr.count > 1 ? arr[1] : 0, arr.count > 2 ? arr[2] : 0, arr.count > 3 ? arr[3] : 1)
    }

    init(hex: String, name: String, rgba: SIMD4<Float>) {
        self.hex = hex
        self.name = name
        self.rgba = rgba
    }

    /// Create a PaletteColor from RGBA float values (0.0-1.0)
    static func from(rgba: SIMD4<Float>, name: String) -> PaletteColor {
        let r = Int(max(0, min(255, rgba.x * 255)))
        let g = Int(max(0, min(255, rgba.y * 255)))
        let b = Int(max(0, min(255, rgba.z * 255)))
        let hex = String(format: "#%02X%02X%02X", r, g, b)
        return PaletteColor(hex: hex, name: name, rgba: rgba)
    }
}
