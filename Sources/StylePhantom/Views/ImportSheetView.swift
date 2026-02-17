import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Real import sheet with drag-and-drop, file browsing, and progress tracking
struct ImportSheetView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ImportViewModel()
    @State private var isDragging = false
    @State private var droppedFileCount = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(24)

            Divider()

            if viewModel.isImporting {
                progressView
                    .padding(24)
            } else if viewModel.importedArtifactCount > 0 && !viewModel.isImporting {
                completionView
                    .padding(24)
            } else {
                // Drop zone & controls
                dropZone
                    .padding(24)
            }
        }
        .frame(width: 520, height: 420)
        .background(.ultraThinMaterial)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Import Artifacts")
                    .font(.title2.weight(.bold))

                Text("Drop images or browse to add artwork to your library")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if viewModel.isImporting {
                    viewModel.cancelImport()
                }
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        VStack(spacing: 20) {
            // Drop area
            ZStack {
                RoundedRectangle(cornerRadius: PhantomTheme.cornerRadius)
                    .strokeBorder(
                        isDragging ? PhantomTheme.accentViolet : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .background {
                        RoundedRectangle(cornerRadius: PhantomTheme.cornerRadius)
                            .fill(isDragging ? PhantomTheme.accentViolet.opacity(0.08) : Color.clear)
                    }
                    .animation(PhantomTheme.quickSpring, value: isDragging)

                VStack(spacing: 16) {
                    Image(systemName: isDragging ? "arrow.down.circle.fill" : "arrow.down.doc.fill")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(isDragging ? PhantomTheme.accentViolet : .secondary)
                        .symbolEffect(.bounce, value: isDragging)

                    VStack(spacing: 6) {
                        Text(isDragging ? "Release to import" : "Drop images here")
                            .font(.headline)
                        Text("JPEG, PNG, HEIC, TIFF, WebP")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(minHeight: 180)
            .dropDestination(for: URL.self) { urls, _ in
                let imageURLs = filterImageURLs(urls)
                guard !imageURLs.isEmpty else { return false }
                viewModel.startImport(urls: imageURLs, context: modelContext)
                return true
            } isTargeted: { targeted in
                isDragging = targeted
            }

            // Controls row
            HStack {
                Toggle("Auto-extract style vectors", isOn: $viewModel.autoExtractVectors)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .toggleStyle(.checkbox)

                Spacer()

                Button("Browse Files...") {
                    openFilePicker()
                }
                .buttonStyle(.borderedProminent)
                .tint(PhantomTheme.accentViolet)
            }

            // Error message
            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.errorMessage = nil
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(PhantomTheme.accentViolet)
                }
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.yellow.opacity(0.08))
                }
            }
        }
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated import icon
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(PhantomTheme.brandGradient)
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text("Importing...")
                    .font(.headline)

                Text(viewModel.currentFileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // Progress bar
            VStack(spacing: 6) {
                ProgressView(value: viewModel.importProgress)
                    .tint(PhantomTheme.accentViolet)

                HStack {
                    Text("\(viewModel.completedCount) of \(viewModel.totalCount)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Text("\(Int(viewModel.importProgress * 100))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Cancel button
            Button("Cancel") {
                viewModel.cancelImport()
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            VStack(spacing: 6) {
                Text("Import Complete")
                    .font(.headline)

                Text("\(viewModel.importedArtifactCount) artifact\(viewModel.importedArtifactCount == 1 ? "" : "s") imported")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Import More") {
                    viewModel.importedArtifactCount = 0
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(PhantomTheme.accentViolet)
            }
        }
    }

    // MARK: - File Picker

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .jpeg, .png, .heic, .tiff, .webP]
        panel.message = "Select images to import into Style Phantom"
        panel.prompt = "Import"

        if panel.runModal() == .OK {
            let urls = panel.urls
            if !urls.isEmpty {
                viewModel.startImport(urls: urls, context: modelContext)
            }
        }
    }

    // MARK: - Helpers

    private func filterImageURLs(_ urls: [URL]) -> [URL] {
        urls.filter { url in
            guard let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
                  let contentType = resourceValues.contentType else {
                // If we can't determine the type, check extension
                let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "webp"]
                return imageExtensions.contains(url.pathExtension.lowercased())
            }
            return contentType.conforms(to: .image)
        }
    }
}
