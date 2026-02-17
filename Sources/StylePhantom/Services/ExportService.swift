import Foundation

// MARK: - Export Formats

enum PaletteExportFormat: String, CaseIterable, Sendable {
    case json = "JSON"
    case css = "CSS"
    case ase = "ASE"

    var fileExtension: String {
        switch self {
        case .json: "json"
        case .css: "css"
        case .ase: "ase"
        }
    }
}

enum LayoutExportFormat: String, CaseIterable, Sendable {
    case json = "JSON"
    case svg = "SVG"
    case figmaTokens = "Figma Tokens"

    var fileExtension: String {
        switch self {
        case .json: "json"
        case .svg: "svg"
        case .figmaTokens: "json"
        }
    }
}

// MARK: - Export Errors

enum ExportError: LocalizedError, Sendable {
    case emptyPalette
    case invalidLayout
    case encodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyPalette: "No colors to export"
        case .invalidLayout: "Invalid layout grid parameters"
        case .encodingFailed(let detail): "Export encoding failed: \(detail)"
        }
    }
}

// MARK: - Export Service

final class ExportService: Sendable {

    // MARK: - Palette Export

    func exportPalette(_ palette: [PaletteColor], format: PaletteExportFormat) throws -> Data {
        guard !palette.isEmpty else { throw ExportError.emptyPalette }

        switch format {
        case .json:
            return try exportPaletteJSON(palette)
        case .css:
            return try exportPaletteCSS(palette)
        case .ase:
            return try exportPaletteASE(palette)
        }
    }

    // MARK: JSON

    private func exportPaletteJSON(_ palette: [PaletteColor]) throws -> Data {
        let entries = palette.map { color -> [String: Any] in
            [
                "hex": color.hex,
                "name": color.name,
                "rgba": [
                    "r": Double(color.rgba.x),
                    "g": Double(color.rgba.y),
                    "b": Double(color.rgba.z),
                    "a": Double(color.rgba.w)
                ]
            ]
        }
        return try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: CSS

    private func exportPaletteCSS(_ palette: [PaletteColor]) throws -> Data {
        var css = ":root {\n"
        for (index, color) in palette.enumerated() {
            let varName = color.name
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
            css += "  --color-\(varName)-\(index + 1): \(color.hex);\n"
        }
        css += "}\n"
        guard let data = css.data(using: .utf8) else {
            throw ExportError.encodingFailed("CSS encoding failed")
        }
        return data
    }

    // MARK: ASE (Adobe Swatch Exchange)

    func exportPaletteASE(_ palette: [PaletteColor]) throws -> Data {
        var data = Data()

        // Magic bytes: "ASEF"
        data.append(contentsOf: [0x41, 0x53, 0x45, 0x46])

        // Version: 1.0 (two UInt16 big-endian)
        appendUInt16BigEndian(&data, 1) // major
        appendUInt16BigEndian(&data, 0) // minor

        // Block count
        appendUInt32BigEndian(&data, UInt32(palette.count))

        // Color entries
        for color in palette {
            // Block type: 0x0001 (color entry)
            appendUInt16BigEndian(&data, 0x0001)

            // Build block data first to calculate length
            var blockData = Data()

            // Name: UTF-16BE with null terminator, length includes null
            let nameChars = Array(color.name.utf16)
            let nameLength = UInt16(nameChars.count + 1) // +1 for null terminator
            appendUInt16BigEndian(&blockData, nameLength)
            for char in nameChars {
                appendUInt16BigEndian(&blockData, char)
            }
            // Null terminator
            appendUInt16BigEndian(&blockData, 0x0000)

            // Color model: "RGB " (4 ASCII bytes)
            blockData.append(contentsOf: [0x52, 0x47, 0x42, 0x20])

            // RGB float values (big-endian Float32)
            appendFloat32BigEndian(&blockData, color.rgba.x)
            appendFloat32BigEndian(&blockData, color.rgba.y)
            appendFloat32BigEndian(&blockData, color.rgba.z)

            // Color type: 0 = Global
            appendUInt16BigEndian(&blockData, 0x0000)

            // Block length (UInt32 big-endian)
            appendUInt32BigEndian(&data, UInt32(blockData.count))
            data.append(blockData)
        }

        return data
    }

    // MARK: - Layout Export

    func exportLayout(_ layout: LayoutGrid, format: LayoutExportFormat) throws -> Data {
        guard layout.isValid else { throw ExportError.invalidLayout }

        switch format {
        case .json:
            return try exportLayoutJSON(layout)
        case .svg:
            return try exportLayoutSVG(layout)
        case .figmaTokens:
            return try exportLayoutFigmaTokens(layout)
        }
    }

    // MARK: Layout JSON (Design Token Format)

    private func exportLayoutJSON(_ layout: LayoutGrid) throws -> Data {
        let token: [String: Any] = [
            "grid": [
                "columns": layout.columns,
                "rows": layout.rows,
                "gutter": ["value": Double(layout.gutterWidth), "unit": "px"],
                "margin": ["value": Double(layout.marginWidth), "unit": "px"]
            ],
            "aspectRatios": layout.aspectRatios.map { Double($0) }
        ]
        return try JSONSerialization.data(withJSONObject: token, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: Layout SVG

    private func exportLayoutSVG(_ layout: LayoutGrid) throws -> Data {
        let totalWidth: Float = Float(layout.columns) * 100 + Float(layout.columns - 1) * layout.gutterWidth + 2 * layout.marginWidth
        let totalHeight: Float = Float(layout.rows) * 80 + Float(layout.rows - 1) * layout.gutterWidth + 2 * layout.marginWidth

        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(Int(totalWidth)) \(Int(totalHeight))" width="\(Int(totalWidth))" height="\(Int(totalHeight))">
          <style>
            .grid-line { stroke: #9B8EC4; stroke-width: 0.5; stroke-dasharray: 4,4; }
            .margin-line { stroke: #E57373; stroke-width: 0.5; }
            .label { font-family: system-ui; font-size: 10px; fill: #888; }
            .cell { fill: rgba(139, 92, 246, 0.08); stroke: rgba(139, 92, 246, 0.2); stroke-width: 1; }
          </style>

        """

        // Margin lines
        svg += "  <!-- Margins -->\n"
        svg += "  <line x1=\"\(Int(layout.marginWidth))\" y1=\"0\" x2=\"\(Int(layout.marginWidth))\" y2=\"\(Int(totalHeight))\" class=\"margin-line\"/>\n"
        svg += "  <line x1=\"\(Int(totalWidth - layout.marginWidth))\" y1=\"0\" x2=\"\(Int(totalWidth - layout.marginWidth))\" y2=\"\(Int(totalHeight))\" class=\"margin-line\"/>\n"

        // Grid cells
        svg += "  <!-- Grid Cells -->\n"
        let cellW: Float = 100
        let cellH: Float = 80
        for row in 0..<layout.rows {
            for col in 0..<layout.columns {
                let x = layout.marginWidth + Float(col) * (cellW + layout.gutterWidth)
                let y = layout.marginWidth + Float(row) * (cellH + layout.gutterWidth)
                svg += "  <rect x=\"\(Int(x))\" y=\"\(Int(y))\" width=\"\(Int(cellW))\" height=\"\(Int(cellH))\" rx=\"4\" class=\"cell\"/>\n"

                // Column/row label
                svg += "  <text x=\"\(Int(x + 4))\" y=\"\(Int(y + 14))\" class=\"label\">\(col + 1)x\(row + 1)</text>\n"
            }
        }

        // Gutter annotations
        if layout.columns > 1 {
            let gutterX = layout.marginWidth + cellW + layout.gutterWidth * 0.5
            svg += "  <text x=\"\(Int(gutterX))\" y=\"\(Int(totalHeight - 4))\" class=\"label\" text-anchor=\"middle\">\(Int(layout.gutterWidth))px gutter</text>\n"
        }

        svg += "</svg>\n"

        guard let data = svg.data(using: .utf8) else {
            throw ExportError.encodingFailed("SVG encoding failed")
        }
        return data
    }

    // MARK: Figma Tokens

    private func exportLayoutFigmaTokens(_ layout: LayoutGrid) throws -> Data {
        let tokens: [String: Any] = [
            "grid": [
                "columns": ["value": "\(layout.columns)", "type": "sizing"],
                "rows": ["value": "\(layout.rows)", "type": "sizing"],
                "gutter": ["value": "\(Int(layout.gutterWidth))", "type": "spacing"],
                "margin": ["value": "\(Int(layout.marginWidth))", "type": "spacing"]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: tokens, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Binary Helpers

    private func appendUInt16BigEndian(_ data: inout Data, _ value: UInt16) {
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    private func appendUInt32BigEndian(_ data: inout Data, _ value: UInt32) {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    private func appendFloat32BigEndian(_ data: inout Data, _ value: Float) {
        var bigEndian = value.bitPattern.bigEndian
        data.append(Data(bytes: &bigEndian, count: 4))
    }
}
