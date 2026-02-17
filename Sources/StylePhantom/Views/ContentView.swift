import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedPhase: AestheticPhase?
    @State private var selectedArtifact: CreativeArtifact?
    @State private var showImportSheet = false
    @State private var showEvolutionViewer = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var sidebarVM = SidebarViewModel()
    @State private var galleryVM = GalleryViewModel()
    @State private var evolutionVM = EvolutionViewModel()

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(
                    selectedPhase: $selectedPhase,
                    viewModel: sidebarVM,
                    onImport: { showImportSheet = true },
                    onShowEvolution: { showEvolutionViewer.toggle() }
                )
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
            } content: {
                if showEvolutionViewer {
                    EvolutionViewerView(viewModel: evolutionVM)
                } else {
                    ArtifactGalleryView(
                        selectedPhase: selectedPhase,
                        selectedArtifact: $selectedArtifact,
                        onImport: { showImportSheet = true }
                    )
                    .navigationSplitViewColumnWidth(min: 340, ideal: 500)
                }
            } detail: {
                if showEvolutionViewer {
                    // Show evolution detail when in evolution mode
                    evolutionDetailView
                } else if let artifact = selectedArtifact {
                    ArtifactDetailView(artifact: artifact)
                } else {
                    WelcomeView()
                }
            }

            // Timeline scrubber at bottom
            TimelineScrubberView(
                selectedPhase: $selectedPhase,
                timelinePosition: $sidebarVM.timelinePosition
            )
        }
        .sheet(isPresented: $showImportSheet) {
            ImportSheetView(isPresented: $showImportSheet)
        }
        .onChange(of: selectedPhase) { _, newPhase in
            if let phase = newPhase {
                evolutionVM.loadPhase(phase)
            }
        }
    }

    // MARK: - Evolution Detail

    private var evolutionDetailView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let phase = evolutionVM.currentPhase {
                    // Phase info header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(phase.label)
                            .font(.title2.weight(.bold))
                            .gradientText()

                        Text(phase.dateRangeFormatted)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("\(phase.artifacts.count) artifacts in this phase")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Divider()

                    // Projection info
                    if let projection = evolutionVM.projection {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "Projection", icon: "arrow.triangle.branch")

                            HStack(spacing: 16) {
                                MetadataItem(label: "Confidence", value: projection.confidenceFormatted)
                                MetadataItem(label: "Created", value: projection.creationDate.formatted(date: .abbreviated, time: .omitted))
                            }
                        }

                        Divider()

                        // Structural notes
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "Style Direction", icon: "text.alignleft")

                            Text(evolutionVM.structuralNotes)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text("No projection computed yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Recompute evolution to generate projections.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    EmptyStateView.projection()
                }
            }
            .padding(24)
        }
        .navigationTitle("Evolution Detail")
    }
}

// MARK: - Welcome View (Detail placeholder)

struct WelcomeView: View {
    @State private var animateGlow = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                PhantomTheme.accentViolet.opacity(0.15),
                                PhantomTheme.accentCoral.opacity(0.05),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(animateGlow ? 1.15 : 0.95)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animateGlow)

                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(PhantomTheme.brandGradient)
                    .rotationEffect(.degrees(animateGlow ? 5 : -5))
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: animateGlow)
            }

            VStack(spacing: 12) {
                Text("Style Phantom")
                    .font(.largeTitle.weight(.bold))
                    .gradientText()

                Text("Map your creative evolution.\nDiscover where your taste is heading.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            HStack(spacing: 32) {
                QuickTip(icon: "square.and.arrow.down", title: "Import", subtitle: "Drop your artwork")
                QuickTip(icon: "cpu", title: "Analyze", subtitle: "AI style extraction")
                QuickTip(icon: "chart.line.uptrend.xyaxis", title: "Evolve", subtitle: "See your trajectory")
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [
                    PhantomTheme.accentViolet.opacity(0.03),
                    PhantomTheme.accentCoral.opacity(0.02),
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .onAppear { animateGlow = true }
    }
}

struct QuickTip: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(PhantomTheme.accentViolet.opacity(0.7))
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(PhantomTheme.accentViolet.opacity(0.1))
                }

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
