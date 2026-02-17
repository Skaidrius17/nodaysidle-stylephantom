import Foundation
import UniformTypeIdentifiers
import CoreGraphics
import ImageIO
import SwiftData

/// Progress report emitted during bulk import
struct ImportProgress: Sendable {
    let completed: Int
    let total: Int
    let currentFileName: String
    let artifactID: UUID?
}

/// Handles file validation, thumbnail generation, bookmarks, and artifact creation
final class ArtifactImportService: Sendable {

    static let maxFileSize: Int = 100 * 1024 * 1024 // 100 MB
    static let thumbnailMaxDimension: Int = 512
    static let supportedTypes: [UTType] = [.image, .jpeg, .png, .heic, .tiff, .webP]

    // MARK: - Validation

    func validateFile(url: URL) throws {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])

        guard let fileSize = resourceValues.fileSize, fileSize <= Self.maxFileSize else {
            throw ImportError.fileTooLarge(url.lastPathComponent)
        }

        guard let contentType = resourceValues.contentType,
              Self.supportedTypes.contains(where: { contentType.conforms(to: $0) }) else {
            throw ImportError.unsupportedFormat(url.lastPathComponent)
        }
    }

    // MARK: - Thumbnail Generation

    func generateThumbnail(for url: URL, maxDimension: Int = thumbnailMaxDimension) throws -> Data {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImportError.thumbnailFailed(url.lastPathComponent)
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImportError.thumbnailFailed(url.lastPathComponent)
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ImportError.thumbnailFailed(url.lastPathComponent)
        }

        let compressionOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.82,
        ]
        CGImageDestinationAddImage(destination, thumbnail, compressionOptions as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ImportError.thumbnailFailed(url.lastPathComponent)
        }

        return mutableData as Data
    }

    // MARK: - Bookmarks

    func createBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    func resolveBookmark(_ data: Data) throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale {
            throw ImportError.staleBookmark(url.lastPathComponent)
        }
        return url
    }

    // MARK: - Bulk Import (MainActor for ModelContext safety)

    @MainActor
    func importArtifacts(
        from urls: [URL],
        into context: ModelContext,
        progress: (ImportProgress) -> Void
    ) throws {
        var completed = 0
        let total = urls.count

        // Pre-fetch existing bookmark data for duplicate detection
        let fetchDescriptor = FetchDescriptor<CreativeArtifact>()
        let existing = try context.fetch(fetchDescriptor)
        let existingBookmarks = Set(existing.map { $0.imageBookmarkData })

        for url in urls {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            do {
                try validateFile(url: url)

                // Generate bookmark for persistent access
                let bookmarkData: Data
                do {
                    bookmarkData = try createBookmark(for: url)
                } catch {
                    bookmarkData = url.absoluteString.data(using: .utf8) ?? Data()
                }

                // Duplicate check
                if existingBookmarks.contains(bookmarkData) {
                    completed += 1
                    progress(ImportProgress(completed: completed, total: total, currentFileName: url.lastPathComponent, artifactID: nil))
                    continue
                }

                let thumbnailData = try generateThumbnail(for: url)

                let artifact = CreativeArtifact(
                    imageBookmarkData: bookmarkData,
                    thumbnailData: thumbnailData
                )
                context.insert(artifact)

                completed += 1
                progress(ImportProgress(completed: completed, total: total, currentFileName: url.lastPathComponent, artifactID: artifact.id))
            } catch {
                completed += 1
                progress(ImportProgress(completed: completed, total: total, currentFileName: url.lastPathComponent, artifactID: nil))
            }
        }

        try context.save()
    }
}

// MARK: - Import Errors

enum ImportError: LocalizedError, Sendable {
    case fileTooLarge(String)
    case unsupportedFormat(String)
    case thumbnailFailed(String)
    case staleBookmark(String)
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let name): "File too large: \(name) (max 100MB)"
        case .unsupportedFormat(let name): "Unsupported format: \(name)"
        case .thumbnailFailed(let name): "Failed to generate thumbnail: \(name)"
        case .staleBookmark(let name): "Bookmark is stale for: \(name)"
        case .importFailed(let name): "Import failed: \(name)"
        }
    }
}
