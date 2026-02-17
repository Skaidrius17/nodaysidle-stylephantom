import SwiftUI
import SwiftData

struct ArtifactDetailView: View {
    let artifact: CreativeArtifact
    @Namespace private var detailNamespace
    @Environment(\.modelContext) private var modelContext

    @State private var fullImage: NSImage?
    @State private var isExtracting = false
    @State private var extractionError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Large image preview
                imageSection

                // Metadata section
                metadataSection

                // Style vector section
                if let vector = artifact.styleVector {
                    styleVectorSection(vector)
                } else {
                    extractionPrompt
                }

                // Tags section
                if !artifact.manualTags.isEmpty {
                    tagsSection
                }
            }
            .padding(24)
        }
        .navigationTitle("Artifact Detail")
        .task {
            fullImage = NSImage(data: artifact.thumbnailData)
        }
    }

    // MARK: - Image

    private var imageSection: some View {
        Group {
            if let image = fullImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: PhantomTheme.cornerRadius))
                    .shadow(color: PhantomTheme.cardShadow, radius: 12, y: 6)
            } else {
                RoundedRectangle(cornerRadius: PhantomTheme.cornerRadius)
                    .fill(.ultraThinMaterial)
                    .frame(height: 300)
                    .overlay {
                        ProgressView()
                    }
            }
        }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Details", icon: "info.circle")

            HStack(spacing: 24) {
                MetadataItem(label: "Imported", value: artifact.importDate.formatted(date: .abbreviated, time: .shortened))
                MetadataItem(label: "Phase", value: artifact.phase?.label ?? "Unassigned")
                MetadataItem(label: "Style Vector", value: artifact.styleVectorData != nil ? "Extracted" : "Pending")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Style Vector

    private func styleVectorSection(_ vector: StyleVector) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Style Dimensions", icon: "wand.and.stars")

            // Color palette
            VStack(alignment: .leading, spacing: 8) {
                Text("DOMINANT COLORS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)

                HStack(spacing: 6) {
                    ForEach(0..<vector.colorPalette.count, id: \.self) { i in
                        let color = vector.colorPalette[i]
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(
                                red: Double(color.x),
                                green: Double(color.y),
                                blue: Double(color.z)
                            ))
                            .frame(height: 36)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                            }
                    }
                }
            }

            // Composition bars
            VStack(alignment: .leading, spacing: 8) {
                Text("COMPOSITION")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)

                let labels = ["Thirds", "Symmetry", "Focal", "Space", "Depth", "Layers", "Balance", "Flow"]
                ForEach(0..<8, id: \.self) { i in
                    DimensionBar(label: labels[i], value: Double(vector.composition[i]))
                }
            }

            // Complexity gauge
            VStack(alignment: .leading, spacing: 8) {
                Text("COMPLEXITY")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)

                DimensionBar(label: "Overall", value: Double(vector.complexity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Extraction Prompt

    private var extractionPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.title2)
                .foregroundStyle(PhantomTheme.accentViolet)

            Text("Style Not Yet Extracted")
                .font(.subheadline.weight(.medium))

            Text("Run style extraction to analyze this artifact's visual dimensions.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if isExtracting {
                ProgressView("Extracting...")
                    .controlSize(.small)
            } else {
                Button("Extract Style") {
                    Task {
                        isExtracting = true
                        extractionError = nil
                        do {
                            let vm = GalleryViewModel()
                            try await vm.extractStyle(for: artifact, context: modelContext)
                        } catch {
                            extractionError = error.localizedDescription
                        }
                        isExtracting = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(PhantomTheme.accentViolet)
            }

            if let error = extractionError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: PhantomTheme.cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: PhantomTheme.cornerRadius)
                        .strokeBorder(PhantomTheme.accentViolet.opacity(0.2), lineWidth: 1)
                }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Tags", icon: "tag")

            FlowLayout(spacing: 6) {
                ForEach(artifact.manualTags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(.quaternary)
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(PhantomTheme.accentViolet)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
    }
}

struct MetadataItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
}

struct DimensionBar: View {
    let label: String
    let value: Double

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)

                    Capsule()
                        .fill(PhantomTheme.brandGradient)
                        .frame(width: max(4, geo.size.width * value))
                }
            }
            .frame(height: 6)

            Text(String(format: "%.0f%%", value * 100))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? .infinity, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
            maxWidth = max(maxWidth, x)
        }

        return (CGSize(width: maxWidth, height: y + maxHeight), positions)
    }
}
