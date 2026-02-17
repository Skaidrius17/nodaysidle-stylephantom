import SwiftUI
import SwiftData

struct EvolutionViewerView: View {
    @Bindable var viewModel: EvolutionViewModel
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showExportSheet = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.currentPhase != nil {
                // Header
                evolutionHeader

                Divider()

                // Main content: current vs projected
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // Current phase
                        phaseColumn(
                            title: "Current Phase",
                            subtitle: viewModel.currentPhase?.label ?? "",
                            palette: currentPalette,
                            layout: currentLayout,
                            confidence: 1.0,
                            isProjected: false
                        )
                        .frame(width: geo.size.width * 0.5)

                        // Divider with drag handle
                        refinementDivider

                        // Projected / interpolated
                        phaseColumn(
                            title: viewModel.refinementFactor > 0.1 ? "Interpolated" : "Projected",
                            subtitle: "Next Direction",
                            palette: viewModel.interpolatedPalette,
                            layout: viewModel.interpolatedLayout,
                            confidence: viewModel.projection?.confidence ?? 0,
                            isProjected: true
                        )
                        .frame(width: geo.size.width * 0.5 - 3)
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                let t = Float(clamp(value.location.x / geo.size.width, min: 0, max: 1))
                                viewModel.refinementFactor = t
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                }

                Divider()

                // Structural notes
                notesSection
            } else {
                EmptyStateView.projection()
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportDialogView(
                isPresented: $showExportSheet,
                palette: viewModel.interpolatedPalette,
                layout: viewModel.interpolatedLayout
            )
        }
    }

    // MARK: - Current Phase Palette (non-interpolated)

    private var currentPalette: [PaletteColor] {
        guard let vector = viewModel.currentPhase?.centroidVector else { return [] }
        return ProjectionGenerator().generatePalette(from: vector)
    }

    private var currentLayout: LayoutGrid {
        guard let vector = viewModel.currentPhase?.centroidVector else { return .default }
        return ProjectionGenerator().generateLayout(from: vector)
    }

    // MARK: - Header

    private var evolutionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Evolution Viewer")
                    .font(.headline.weight(.bold))
                    .gradientText()

                Text("Drag horizontally to interpolate between current and projected style")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Refinement indicator
            HStack(spacing: 8) {
                Text("Refinement")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text("\(Int(viewModel.refinementFactor * 100))%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(PhantomTheme.accentViolet)
            }

            Button {
                showExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.currentPhase == nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Phase Column

    private func phaseColumn(
        title: String,
        subtitle: String,
        palette: [PaletteColor],
        layout: LayoutGrid,
        confidence: Double,
        isProjected: Bool
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Column header
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if isProjected {
                            Text("\(Int(confidence * 100))% confidence")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background {
                                    Capsule().fill(.quaternary)
                                }
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Palette swatches
                PaletteSwatchView(palette: palette)

                // Layout grid preview
                LayoutGridPreview(layout: layout)
            }
            .padding(16)
        }
    }

    // MARK: - Refinement Divider

    private var refinementDivider: some View {
        Rectangle()
            .fill(isDragging ? PhantomTheme.accentViolet : Color.gray.opacity(0.3))
            .frame(width: 3)
            .overlay {
                // Drag handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(isDragging ? PhantomTheme.accentViolet : .secondary)
                    .frame(width: 6, height: 40)
                    .shadow(color: isDragging ? PhantomTheme.glowShadow : .clear, radius: 6)
            }
            .animation(PhantomTheme.quickSpring, value: isDragging)
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Structural Notes", icon: "text.alignleft")

            Text(viewModel.structuralNotes)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, min), max)
    }
}

// MARK: - Palette Swatch View

struct PaletteSwatchView: View {
    let palette: [PaletteColor]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COLOR PALETTE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)

            HStack(spacing: 6) {
                ForEach(palette) { color in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(
                                red: Double(color.rgba.x),
                                green: Double(color.rgba.y),
                                blue: Double(color.rgba.z)
                            ))
                            .frame(height: 44)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                            }
                            .accessibilityLabel("\(color.name) color swatch")

                        Text(color.name)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)

                        Text(color.hex)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
                }
            }
        }
    }
}

// MARK: - Layout Grid Preview

struct LayoutGridPreview: View {
    let layout: LayoutGrid

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LAYOUT GRID")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)

            // Visual grid
            let cellWidth: CGFloat = 28
            let cellHeight: CGFloat = 24
            let gutter = CGFloat(layout.gutterWidth) * 0.4

            VStack(spacing: gutter) {
                ForEach(0..<layout.rows, id: \.self) { row in
                    HStack(spacing: gutter) {
                        ForEach(0..<layout.columns, id: \.self) { col in
                            let index = row * layout.columns + col
                            let ratio = index < layout.aspectRatios.count ? CGFloat(layout.aspectRatios[index]) : 1.0
                            RoundedRectangle(cornerRadius: 3)
                                .fill(PhantomTheme.accentViolet.opacity(0.15 + Double(index) * 0.05))
                                .frame(width: cellWidth * ratio, height: cellHeight)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(PhantomTheme.accentViolet.opacity(0.3), lineWidth: 0.5)
                                }
                        }
                    }
                }
            }
            .padding(CGFloat(layout.marginWidth) * 0.3)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary.opacity(0.5))
            }

            // Grid stats
            HStack(spacing: 16) {
                gridStat(label: "Columns", value: "\(layout.columns)")
                gridStat(label: "Rows", value: "\(layout.rows)")
                gridStat(label: "Gutter", value: "\(Int(layout.gutterWidth))pt")
                gridStat(label: "Margin", value: "\(Int(layout.marginWidth))pt")
            }
        }
    }

    private func gridStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption2.monospacedDigit().weight(.medium))
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.quaternary)
        }
    }
}
