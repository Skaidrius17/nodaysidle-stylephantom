import SwiftUI

struct ExportDialogView: View {
    @Binding var isPresented: Bool
    let palette: [PaletteColor]
    let layout: LayoutGrid

    @State private var exportVM = ExportViewModel()
    @State private var exportMode: ExportMode = .palette

    enum ExportMode: String, CaseIterable {
        case palette = "Palette"
        case layout = "Layout"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundStyle(PhantomTheme.accentViolet)

                Text("Export")
                    .font(.headline.weight(.bold))

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Content
            VStack(spacing: 16) {
                // Mode picker
                Picker("Export", selection: $exportMode) {
                    ForEach(ExportMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                // Format picker
                Group {
                    switch exportMode {
                    case .palette:
                        Picker("Format", selection: $exportVM.paletteFormat) {
                            ForEach(PaletteExportFormat.allCases, id: \.self) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                    case .layout:
                        Picker("Format", selection: $exportVM.layoutFormat) {
                            ForEach(LayoutExportFormat.allCases, id: \.self) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                    }
                }

                // Preview
                VStack(alignment: .leading, spacing: 6) {
                    Text("PREVIEW")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)

                    ScrollView {
                        Text(exportVM.exportPreview)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: 160)
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black.opacity(0.2))
                    }
                }

                // Error
                if let error = exportVM.exportError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Export...") {
                    switch exportMode {
                    case .palette:
                        exportVM.exportPaletteToFile(palette)
                    case .layout:
                        exportVM.exportLayoutToFile(layout)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(PhantomTheme.accentViolet)
                .disabled(exportVM.isExporting)
            }
            .padding(20)
        }
        .frame(width: 480, height: 480)
        .onAppear { updatePreview() }
        .onChange(of: exportMode) { _, _ in updatePreview() }
        .onChange(of: exportVM.paletteFormat) { _, _ in updatePreview() }
        .onChange(of: exportVM.layoutFormat) { _, _ in updatePreview() }
    }

    private func updatePreview() {
        switch exportMode {
        case .palette:
            exportVM.previewPalette(palette)
        case .layout:
            exportVM.previewLayout(layout)
        }
    }
}
