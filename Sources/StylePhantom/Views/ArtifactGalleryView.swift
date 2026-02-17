import SwiftUI
import SwiftData

struct ArtifactGalleryView: View {
    let selectedPhase: AestheticPhase?
    @Binding var selectedArtifact: CreativeArtifact?
    var onImport: () -> Void

    @Query(sort: \CreativeArtifact.importDate, order: .reverse) private var allArtifacts: [CreativeArtifact]
    @Namespace private var galleryNamespace

    private var artifacts: [CreativeArtifact] {
        if let phase = selectedPhase {
            return allArtifacts.filter { $0.phase?.id == phase.id }
        }
        return allArtifacts
    }

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 14)]

    var body: some View {
        Group {
            if allArtifacts.isEmpty {
                EmptyStateView.gallery(onImport: onImport)
            } else {
                galleryGrid
            }
        }
        .navigationTitle(selectedPhase?.label ?? "All Artifacts")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                artifactCountBadge
                sortMenu
            }
        }
    }

    // MARK: - Gallery Grid

    private var galleryGrid: some View {
        ScrollView {
            if artifacts.isEmpty {
                EmptyStateView(
                    icon: "photo.on.rectangle.angled",
                    title: "No Artifacts in Phase",
                    subtitle: "This phase doesn't contain any artifacts yet."
                )
                .frame(minHeight: 400)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(artifacts) { artifact in
                        ArtifactCard(
                            artifact: artifact,
                            isSelected: selectedArtifact?.id == artifact.id,
                            namespace: galleryNamespace
                        )
                        .onTapGesture {
                            withAnimation(PhantomTheme.springAnimation) {
                                selectedArtifact = artifact
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Toolbar Items

    private var artifactCountBadge: some View {
        Text("\(artifacts.count) artifact\(artifacts.count == 1 ? "" : "s")")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(.quaternary)
            }
    }

    private var sortMenu: some View {
        Menu {
            Button("By Date") {}
            Button("By Phase") {}
            Divider()
            Button("Import Artifacts...", action: onImport)
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }
}

// MARK: - Artifact Card

struct ArtifactCard: View {
    let artifact: CreativeArtifact
    var isSelected: Bool = false
    var namespace: Namespace.ID

    @State private var isHovered = false
    @State private var thumbnailImage: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail area
            ZStack {
                if let image = thumbnailImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minHeight: 120, maxHeight: 160)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(PhantomTheme.surfaceGradient)
                        .frame(height: 140)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.quaternary)
                        }
                }

                // Style vector indicator
                if artifact.styleVectorData != nil {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "wand.and.stars")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(5)
                                .background {
                                    Circle()
                                        .fill(PhantomTheme.accentViolet.opacity(0.8))
                                }
                        }
                        Spacer()
                    }
                    .padding(8)
                }
            }
            .matchedGeometryEffect(id: artifact.id, in: namespace)

            // Metadata bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(artifact.importDate, style: .date)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !artifact.manualTags.isEmpty {
                        Text(artifact.manualTags.prefix(2).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let phase = artifact.phase {
                    Circle()
                        .fill(Color(
                            red: Double(phase.dominantColor.r),
                            green: Double(phase.dominantColor.g),
                            blue: Double(phase.dominantColor.b)
                        ))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: PhantomTheme.cardCornerRadius))
        .phantomCard(isSelected: isSelected, isHovered: isHovered)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(PhantomTheme.quickSpring, value: isHovered)
        .onHover { isHovered = $0 }
        .task {
            thumbnailImage = NSImage(data: artifact.thumbnailData)
        }
    }
}
