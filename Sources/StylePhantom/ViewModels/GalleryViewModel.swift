import Foundation
import SwiftData
import Observation
import AppKit

// MARK: - Sort Order

enum ArtifactSortOrder: String, CaseIterable, Sendable {
    case dateNewest = "Newest First"
    case dateOldest = "Oldest First"
    case phase = "By Phase"
}

// MARK: - Thumbnail Cache

/// LRU cache for decoded thumbnail NSImages (max 200 entries)
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private var cache: [UUID: NSImage] = [:]
    private var accessOrder: [UUID] = []
    private let maxEntries = 200

    func image(for artifactID: UUID, data: Data) -> NSImage? {
        if let cached = cache[artifactID] {
            // Move to end (most recent)
            accessOrder.removeAll { $0 == artifactID }
            accessOrder.append(artifactID)
            return cached
        }

        guard let image = NSImage(data: data) else { return nil }

        // Evict oldest if full
        if cache.count >= maxEntries, let oldest = accessOrder.first {
            accessOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }

        cache[artifactID] = image
        accessOrder.append(artifactID)
        return image
    }

    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }
}

// MARK: - Gallery ViewModel

@MainActor
@Observable
final class GalleryViewModel {
    var selectedArtifact: CreativeArtifact?
    var sortOrder: ArtifactSortOrder = .dateNewest
    var searchText = ""

    private let extractor = StyleVectorExtractor()

    /// Sort and optionally filter artifacts
    func sorted(_ artifacts: [CreativeArtifact]) -> [CreativeArtifact] {
        var result = artifacts

        // Filter by search text
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { artifact in
                artifact.manualTags.contains { $0.lowercased().contains(query) }
                || artifact.phase?.label.lowercased().contains(query) == true
            }
        }

        // Sort
        switch sortOrder {
        case .dateNewest:
            result.sort { $0.importDate > $1.importDate }
        case .dateOldest:
            result.sort { $0.importDate < $1.importDate }
        case .phase:
            result.sort { ($0.phase?.label ?? "") < ($1.phase?.label ?? "") }
        }

        return result
    }

    /// Extract style vector for a single artifact
    func extractStyle(for artifact: CreativeArtifact, context: ModelContext) async throws {
        let bookmarkData = artifact.imageBookmarkData

        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, bookmarkDataIsStale: &isStale)

        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let vector = try await extractor.extractVector(from: url)
        artifact.styleVectorData = vector.encodeToPrefixedData()
        try context.save()
    }
}
