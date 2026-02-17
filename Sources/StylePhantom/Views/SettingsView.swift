import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var prefs: UserPreferences?
    @State private var showSyncConfirmation = false

    var body: some View {
        Form {
            // Export Defaults
            Section("Export Defaults") {
                Picker("Palette Format", selection: paletteFormatBinding) {
                    Text("JSON").tag("json")
                    Text("CSS").tag("css")
                    Text("ASE").tag("ase")
                }

                Picker("Layout Format", selection: layoutFormatBinding) {
                    Text("JSON").tag("json")
                    Text("SVG").tag("svg")
                    Text("Figma Tokens").tag("figmaTokens")
                }
            }

            // Evolution Parameters
            Section("Evolution Parameters") {
                Stepper(
                    "Minimum Artifacts: \(prefs?.minimumArtifactThreshold ?? 5)",
                    value: thresholdBinding,
                    in: 3...20
                )

                Toggle("Auto-detect cluster count", isOn: autoClusterBinding)

                if let count = prefs?.preferredClusterCount {
                    Stepper("Cluster Count: \(count)", value: clusterCountBinding, in: 2...10)
                }
            }

            // Sync
            Section("iCloud Sync") {
                Toggle("Enable CloudKit Sync", isOn: syncBinding)

                if prefs?.cloudKitSyncEnabled == true {
                    Label("Syncing artifacts across your Macs", systemImage: "checkmark.icloud")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 380)
        .navigationTitle("Settings")
        .onAppear {
            prefs = UserPreferences.shared(in: modelContext)
        }
        .alert("Enable iCloud Sync?", isPresented: $showSyncConfirmation) {
            Button("Enable") {
                prefs?.cloudKitSyncEnabled = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your artifacts, style vectors, and preferences will sync across your Macs via iCloud.")
        }
    }

    // MARK: - Bindings

    private var paletteFormatBinding: Binding<String> {
        Binding(
            get: { prefs?.defaultPaletteExportFormat ?? "json" },
            set: { prefs?.defaultPaletteExportFormat = $0 }
        )
    }

    private var layoutFormatBinding: Binding<String> {
        Binding(
            get: { prefs?.defaultLayoutExportFormat ?? "json" },
            set: { prefs?.defaultLayoutExportFormat = $0 }
        )
    }

    private var thresholdBinding: Binding<Int> {
        Binding(
            get: { prefs?.minimumArtifactThreshold ?? 5 },
            set: { prefs?.minimumArtifactThreshold = $0 }
        )
    }

    private var autoClusterBinding: Binding<Bool> {
        Binding(
            get: { prefs?.preferredClusterCount == nil },
            set: { isAuto in
                prefs?.preferredClusterCount = isAuto ? nil : 3
            }
        )
    }

    private var clusterCountBinding: Binding<Int> {
        Binding(
            get: { prefs?.preferredClusterCount ?? 3 },
            set: { prefs?.preferredClusterCount = $0 }
        )
    }

    private var syncBinding: Binding<Bool> {
        Binding(
            get: { prefs?.cloudKitSyncEnabled ?? false },
            set: { newValue in
                if newValue {
                    showSyncConfirmation = true
                } else {
                    prefs?.cloudKitSyncEnabled = false
                }
            }
        )
    }
}
