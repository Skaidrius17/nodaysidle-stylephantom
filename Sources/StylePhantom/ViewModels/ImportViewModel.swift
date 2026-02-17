import Foundation
import SwiftData
import Observation

/// ViewModel managing the import workflow state
@MainActor
@Observable
final class ImportViewModel {
    var isImporting = false
    var importProgress: Double = 0
    var currentFileName = ""
    var completedCount = 0
    var totalCount = 0
    var errorMessage: String?
    var importedArtifactCount = 0
    var autoExtractVectors = true

    private var importTask: Task<Void, Never>?
    private let importService = ArtifactImportService()
    private let extractor = StyleVectorExtractor()

    /// Start importing from the given URLs
    func startImport(urls: [URL], context: ModelContext) {
        guard !urls.isEmpty else { return }
        isImporting = true
        errorMessage = nil
        completedCount = 0
        totalCount = urls.count
        importProgress = 0
        importedArtifactCount = 0
        currentFileName = ""

        importTask = Task { @MainActor in
            var importedArtifactIDs: [UUID] = []

            do {
                // Import files (synchronous on main actor, touches ModelContext)
                try importService.importArtifacts(from: urls, into: context) { progress in
                    self.completedCount = progress.completed
                    self.totalCount = progress.total
                    self.currentFileName = progress.currentFileName
                    self.importProgress = Double(progress.completed) / Double(max(1, progress.total))

                    if let artifactID = progress.artifactID {
                        importedArtifactIDs.append(artifactID)
                        self.importedArtifactCount += 1
                    }
                }

                // Auto-extract style vectors if enabled
                if autoExtractVectors && !importedArtifactIDs.isEmpty {
                    currentFileName = "Extracting style vectors..."

                    let fetchDescriptor = FetchDescriptor<CreativeArtifact>()
                    let allArtifacts = try context.fetch(fetchDescriptor)
                    let importedArtifacts = allArtifacts.filter { importedArtifactIDs.contains($0.id) }

                    try await extractor.batchExtract(
                        artifacts: importedArtifacts,
                        context: context,
                        concurrency: 4
                    )
                }

                isImporting = false
                currentFileName = ""
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }

    /// Cancel the current import operation
    func cancelImport() {
        importTask?.cancel()
        importTask = nil
        isImporting = false
        currentFileName = ""
        importProgress = 0
    }
}
