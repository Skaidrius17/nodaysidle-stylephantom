import SwiftUI
import SwiftData

struct SidebarView: View {
    @Query(sort: \AestheticPhase.dateRangeStart) private var phases: [AestheticPhase]
    @Query private var allArtifacts: [CreativeArtifact]
    @Binding var selectedPhase: AestheticPhase?
    @State private var showAllArtifacts = true
    @Bindable var viewModel: SidebarViewModel
    var onImport: () -> Void
    var onShowEvolution: () -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            Divider()
                .padding(.horizontal)

            if phases.isEmpty {
                emptyPhasesList
            } else {
                phasesList
            }

            Spacer()

            // Error banner
            if let error = viewModel.evolutionError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            Divider()
                .padding(.horizontal)

            sidebarActions
        }
        .frame(minWidth: 220)
    }

    // MARK: - Header

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "paintbrush.pointed.fill")
                .font(.title3)
                .foregroundStyle(PhantomTheme.brandGradient)

            Text("Style Phantom")
                .font(.headline.weight(.bold))
                .gradientText()

            Spacer()

            // Artifact count badge
            Text("\(allArtifacts.count)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    Capsule().fill(.quaternary)
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Phases List

    private var phasesList: some View {
        List(selection: Binding(
            get: { showAllArtifacts ? nil : selectedPhase },
            set: { newValue in
                selectedPhase = newValue
                showAllArtifacts = (newValue == nil)
            }
        )) {
            Button {
                showAllArtifacts = true
                selectedPhase = nil
            } label: {
                Label {
                    Text("All Artifacts")
                        .font(.body.weight(showAllArtifacts ? .semibold : .regular))
                } icon: {
                    Image(systemName: "square.grid.2x2")
                        .foregroundStyle(showAllArtifacts ? PhantomTheme.accentViolet : .secondary)
                }
            }
            .listRowBackground(
                showAllArtifacts
                    ? RoundedRectangle(cornerRadius: 6)
                        .fill(PhantomTheme.accentViolet.opacity(0.15))
                    : nil
            )

            Section("Evolution Phases") {
                ForEach(phases) { phase in
                    PhaseRow(phase: phase, isSelected: selectedPhase == phase)
                        .tag(phase)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty State

    private var emptyPhasesList: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "circle.hexagongrid")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                Text("No Phases Yet")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("Import artwork to begin detecting your aesthetic evolution.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Spacer()
        }
    }

    // MARK: - Actions

    private var sidebarActions: some View {
        VStack(spacing: 6) {
            Button(action: onImport) {
                Label("Import Artifacts", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            Button {
                Task {
                    await viewModel.recomputeEvolution(context: modelContext)
                }
            } label: {
                HStack {
                    if viewModel.isComputingEvolution {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }
                    Label(
                        viewModel.isComputingEvolution ? "Computing..." : "Recompute Evolution",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(allArtifacts.filter({ $0.styleVectorData != nil }).count < 5 || viewModel.isComputingEvolution)

            if !phases.isEmpty {
                Button(action: onShowEvolution) {
                    Label("Evolution Viewer", systemImage: "chart.line.uptrend.xyaxis")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(PhantomTheme.accentViolet)
            }
        }
        .padding(12)
    }
}

// MARK: - Phase Row

struct PhaseRow: View {
    let phase: AestheticPhase
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(
                    Color(
                        red: Double(phase.dominantColor.r),
                        green: Double(phase.dominantColor.g),
                        blue: Double(phase.dominantColor.b)
                    )
                )
                .frame(width: 10, height: 10)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(phase.label)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Text(phase.dateRangeFormatted)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("\(phase.artifacts.count)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    Capsule()
                        .fill(.quaternary)
                }
        }
        .padding(.vertical, 2)
        .listRowBackground(
            isSelected
                ? RoundedRectangle(cornerRadius: 6)
                    .fill(PhantomTheme.accentViolet.opacity(0.15))
                : nil
        )
    }
}
