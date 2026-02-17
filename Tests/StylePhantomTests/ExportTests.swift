import Testing
import Foundation
import simd
@testable import StylePhantom

// MARK: - Test Data

private let testPalette: [PaletteColor] = [
    .from(rgba: SIMD4<Float>(1.0, 0.0, 0.0, 1.0), name: "Red"),
    .from(rgba: SIMD4<Float>(0.0, 0.5, 1.0, 1.0), name: "Sky Blue"),
    .from(rgba: SIMD4<Float>(0.2, 0.8, 0.3, 1.0), name: "Green"),
]

private let testLayout = LayoutGrid(
    columns: 3,
    rows: 2,
    gutterWidth: 16,
    marginWidth: 20,
    aspectRatios: [1.0, 1.2, 0.8, 1.1, 0.9, 1.0]
)

// MARK: - ASE Binary Encoding Tests

@Suite("ASE Export Tests")
struct ASEExportTests {
    let service = ExportService()

    @Test("ASE starts with magic bytes ASEF")
    func magicBytes() throws {
        let data = try service.exportPaletteASE(testPalette)

        #expect(data.count > 4)
        #expect(data[0] == 0x41) // A
        #expect(data[1] == 0x53) // S
        #expect(data[2] == 0x45) // E
        #expect(data[3] == 0x46) // F
    }

    @Test("ASE version is 1.0")
    func version() throws {
        let data = try service.exportPaletteASE(testPalette)

        // Version bytes at offset 4-7 (two UInt16 big-endian)
        let major = UInt16(data[4]) << 8 | UInt16(data[5])
        let minor = UInt16(data[6]) << 8 | UInt16(data[7])
        #expect(major == 1)
        #expect(minor == 0)
    }

    @Test("ASE block count matches palette size")
    func blockCount() throws {
        let data = try service.exportPaletteASE(testPalette)

        // Block count at offset 8-11 (UInt32 big-endian)
        let count = UInt32(data[8]) << 24 | UInt32(data[9]) << 16 | UInt32(data[10]) << 8 | UInt32(data[11])
        #expect(count == UInt32(testPalette.count))
    }

    @Test("ASE color blocks have type 0x0001")
    func colorBlockType() throws {
        let data = try service.exportPaletteASE(testPalette)

        // First block starts at offset 12
        let blockType = UInt16(data[12]) << 8 | UInt16(data[13])
        #expect(blockType == 0x0001)
    }

    @Test("ASE contains RGB color model tag")
    func rgbModelTag() throws {
        let data = try service.exportPaletteASE(testPalette)
        let bytes = Array(data)

        // Search for "RGB " (0x52 0x47 0x42 0x20)
        var found = false
        for i in 0..<(bytes.count - 3) {
            if bytes[i] == 0x52 && bytes[i+1] == 0x47 && bytes[i+2] == 0x42 && bytes[i+3] == 0x20 {
                found = true
                break
            }
        }
        #expect(found)
    }

    @Test("ASE float precision for red channel")
    func floatPrecision() throws {
        // Single red color
        let red = [PaletteColor.from(rgba: SIMD4<Float>(1.0, 0.0, 0.0, 1.0), name: "R")]
        let data = try service.exportPaletteASE(red)
        let bytes = Array(data)

        // Find "RGB " marker, floats follow immediately after
        for i in 0..<(bytes.count - 7) {
            if bytes[i] == 0x52 && bytes[i+1] == 0x47 && bytes[i+2] == 0x42 && bytes[i+3] == 0x20 {
                // R float at i+4 (big-endian)
                let rBits = UInt32(bytes[i+4]) << 24 | UInt32(bytes[i+5]) << 16 | UInt32(bytes[i+6]) << 8 | UInt32(bytes[i+7])
                let rFloat = Float(bitPattern: rBits)
                #expect(abs(rFloat - 1.0) < 1e-6)

                // G float at i+8
                let gBits = UInt32(bytes[i+8]) << 24 | UInt32(bytes[i+9]) << 16 | UInt32(bytes[i+10]) << 8 | UInt32(bytes[i+11])
                let gFloat = Float(bitPattern: gBits)
                #expect(abs(gFloat - 0.0) < 1e-6)
                break
            }
        }
    }
}

// MARK: - Palette Export Format Tests

@Suite("Palette Export Tests")
struct PaletteExportTests {
    let service = ExportService()

    @Test("JSON export produces valid JSON with correct fields")
    func jsonExport() throws {
        let data = try service.exportPalette(testPalette, format: .json)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        #expect(json != nil)
        #expect(json?.count == testPalette.count)
        #expect(json?[0]["hex"] as? String == "#FF0000")
        #expect(json?[0]["name"] as? String == "Red")
    }

    @Test("CSS export produces valid CSS with custom properties")
    func cssExport() throws {
        let data = try service.exportPalette(testPalette, format: .css)
        let css = String(data: data, encoding: .utf8)!

        #expect(css.contains(":root {"))
        #expect(css.contains("--color-red-1: #FF0000;"))
        #expect(css.contains("--color-sky-blue-2:"))
        #expect(css.contains("}"))
    }

    @Test("ASE export produces non-empty binary data")
    func aseExport() throws {
        let data = try service.exportPalette(testPalette, format: .ase)
        #expect(data.count > 12) // At least header + 1 block
    }

    @Test("Empty palette throws error")
    func emptyPalette() throws {
        #expect(throws: ExportError.self) {
            try service.exportPalette([], format: .json)
        }
    }
}

// MARK: - Layout Export Format Tests

@Suite("Layout Export Tests")
struct LayoutExportTests {
    let service = ExportService()

    @Test("JSON export produces valid design token format")
    func jsonExport() throws {
        let data = try service.exportLayout(testLayout, format: .json)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json != nil)
        let grid = json?["grid"] as? [String: Any]
        #expect(grid?["columns"] as? Int == 3)
        #expect(grid?["rows"] as? Int == 2)
    }

    @Test("SVG export produces valid SVG with grid lines")
    func svgExport() throws {
        let data = try service.exportLayout(testLayout, format: .svg)
        let svg = String(data: data, encoding: .utf8)!

        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
        #expect(svg.contains("<rect"))
        #expect(svg.contains("class=\"cell\""))
    }

    @Test("Figma tokens export produces valid token format")
    func figmaExport() throws {
        let data = try service.exportLayout(testLayout, format: .figmaTokens)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json != nil)
        let grid = json?["grid"] as? [String: Any]
        let columns = grid?["columns"] as? [String: Any]
        #expect(columns?["value"] as? String == "3")
        #expect(columns?["type"] as? String == "sizing")
    }

    @Test("All layout formats produce non-empty data")
    func allFormatsNonEmpty() throws {
        for format in LayoutExportFormat.allCases {
            let data = try service.exportLayout(testLayout, format: format)
            #expect(!data.isEmpty)
        }
    }

    @Test("Invalid layout throws error")
    func invalidLayout() throws {
        let bad = LayoutGrid(columns: 0, rows: 0, gutterWidth: -1, marginWidth: -1, aspectRatios: [])
        #expect(throws: ExportError.self) {
            try service.exportLayout(bad, format: .json)
        }
    }
}

// MARK: - Logging Tests

@Suite("Logging Tests")
struct LoggingTests {
    @Test("All loggers are accessible")
    func loggersExist() {
        // Simply verify the static loggers can be accessed without crashing
        _ = AppLog.import
        _ = AppLog.extraction
        _ = AppLog.evolution
        _ = AppLog.projection
        _ = AppLog.export
        _ = AppLog.sync
        _ = AppLog.signposter
    }

    @Test("Measure block returns value")
    func measureSync() {
        let result = AppLog.measure("test") { 42 }
        #expect(result == 42)
    }

    @Test("Measure async block returns value")
    func measureAsync() async {
        let result = await AppLog.measure("test_async") {
            try? await Task.sleep(for: .milliseconds(1))
            return 99
        }
        #expect(result == 99)
    }
}
