import Foundation
import Observation
import AppKit

@MainActor
@Observable
final class ExportViewModel {
    var paletteFormat: PaletteExportFormat = .json
    var layoutFormat: LayoutExportFormat = .json
    var exportPreview: String = ""
    var isExporting = false
    var exportError: String?

    private let exportService = ExportService()

    /// Generate preview text for the selected palette format
    func previewPalette(_ palette: [PaletteColor]) {
        guard !palette.isEmpty else {
            exportPreview = "No palette to preview"
            return
        }

        do {
            let data = try exportService.exportPalette(palette, format: paletteFormat)
            if paletteFormat == .ase {
                exportPreview = "ASE binary (\(data.count) bytes, \(palette.count) colors)"
            } else {
                exportPreview = String(data: data, encoding: .utf8) ?? "Binary data"
            }
        } catch {
            exportPreview = "Preview error: \(error.localizedDescription)"
        }
    }

    /// Generate preview text for the selected layout format
    func previewLayout(_ layout: LayoutGrid) {
        do {
            let data = try exportService.exportLayout(layout, format: layoutFormat)
            exportPreview = String(data: data, encoding: .utf8) ?? "Binary data"
        } catch {
            exportPreview = "Preview error: \(error.localizedDescription)"
        }
    }

    /// Export palette to file via NSSavePanel
    func exportPaletteToFile(_ palette: [PaletteColor]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.data]
        panel.nameFieldStringValue = "palette.\(paletteFormat.fileExtension)"
        panel.title = "Export Palette"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isExporting = true
        exportError = nil

        do {
            let data = try exportService.exportPalette(palette, format: paletteFormat)
            try data.write(to: url)
            isExporting = false
        } catch {
            exportError = error.localizedDescription
            isExporting = false
        }
    }

    /// Export layout to file via NSSavePanel
    func exportLayoutToFile(_ layout: LayoutGrid) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.data]
        panel.nameFieldStringValue = "layout.\(layoutFormat.fileExtension)"
        panel.title = "Export Layout"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isExporting = true
        exportError = nil

        do {
            let data = try exportService.exportLayout(layout, format: layoutFormat)
            try data.write(to: url)
            isExporting = false
        } catch {
            exportError = error.localizedDescription
            isExporting = false
        }
    }
}
