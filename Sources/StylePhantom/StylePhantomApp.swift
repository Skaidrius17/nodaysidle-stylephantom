import SwiftUI
import SwiftData

@main
struct StylePhantomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainerFactory.create()
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 750)

        Settings {
            SettingsView()
        }
        .modelContainer(modelContainer)

        MenuBarExtra("Style Phantom", systemImage: "paintbrush.pointed") {
            MenuBarContent()
                .modelContainer(modelContainer)
        }
    }
}

// MARK: - Menu Bar Content

struct MenuBarContent: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isRecomputing = false

    var body: some View {
        Button("Import Artifacts...") {
            NSApp.activate(ignoringOtherApps: true)
            // Post notification to trigger import sheet
            NotificationCenter.default.post(name: .openImportSheet, object: nil)
        }
        .keyboardShortcut("i", modifiers: [.command, .shift])

        Button(isRecomputing ? "Computing..." : "Recompute Evolution") {
            Task { @MainActor in
                isRecomputing = true
                let vm = SidebarViewModel()
                await vm.recomputeEvolution(context: modelContext)
                isRecomputing = false
            }
        }
        .disabled(isRecomputing)

        Divider()

        Button("Quit Style Phantom") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openImportSheet = Notification.Name("openImportSheet")
}

// MARK: - Window Customization

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.titlebarAppearsTransparent = true
                window.toolbarStyle = .unified
                window.minSize = NSSize(width: 900, height: 600)
                window.backgroundColor = .windowBackgroundColor
            }
        }
    }
}
