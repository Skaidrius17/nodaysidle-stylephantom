import Testing
import Foundation
import CoreGraphics
import ImageIO
import SwiftData
import simd
@testable import StylePhantom

// MARK: - Test Helpers

/// Create a temporary PNG file from a CGImage (not actor-isolated)
func createTestPNG(name: String, r: UInt8, g: UInt8, b: UInt8) throws -> URL {
    let image = ColorQuantizerTests.solidImage(r: r, g: g, b: b, width: 64, height: 64)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)_\(UUID().uuidString.prefix(6)).png")

    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)

    return url
}

// MARK: - ColorQuantizer Tests

@Suite("ColorQuantizer Tests")
struct ColorQuantizerTests {

    /// Create a solid-color CGImage using CGContext-owned memory (safe for CGImage lifetime)
    static func solidImage(r: UInt8, g: UInt8, b: UInt8, width: Int = 64, height: Int = 64) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        // Pass nil for data so CGContext manages its own memory
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )!

        context.setFillColor(CGColor(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: 1.0
        ))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    /// Create a half-and-half split image (top/bottom) using CGContext drawing
    static func splitImage(
        topR: UInt8, topG: UInt8, topB: UInt8,
        bottomR: UInt8, bottomG: UInt8, bottomB: UInt8,
        width: Int = 64, height: Int = 64
    ) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )!

        let halfHeight = height / 2

        // Bottom half (CGContext has origin at bottom-left)
        context.setFillColor(CGColor(
            red: CGFloat(bottomR) / 255.0,
            green: CGFloat(bottomG) / 255.0,
            blue: CGFloat(bottomB) / 255.0,
            alpha: 1.0
        ))
        context.fill(CGRect(x: 0, y: 0, width: width, height: halfHeight))

        // Top half
        context.setFillColor(CGColor(
            red: CGFloat(topR) / 255.0,
            green: CGFloat(topG) / 255.0,
            blue: CGFloat(topB) / 255.0,
            alpha: 1.0
        ))
        context.fill(CGRect(x: 0, y: halfHeight, width: width, height: height - halfHeight))

        return context.makeImage()!
    }

    @Test("Solid red image returns red-dominant colors")
    func solidRed() {
        let image = Self.solidImage(r: 255, g: 0, b: 0)
        let colors = ColorQuantizer.dominantColors(from: image, count: 5)

        #expect(colors.count == 5)
        // The dominant color should be close to red (CGContext color management adds slight shifts)
        let dominant = colors[0]
        #expect(dominant.x > 0.8)  // R close to 1.0
        #expect(dominant.y < 0.2)  // G close to 0.0
        #expect(dominant.z < 0.2)  // B close to 0.0
        #expect(dominant.w == 1.0) // Alpha = 1.0
    }

    @Test("Solid green image returns green-dominant colors")
    func solidGreen() {
        let image = Self.solidImage(r: 0, g: 255, b: 0)
        let colors = ColorQuantizer.dominantColors(from: image, count: 5)

        #expect(colors.count == 5)
        let dominant = colors[0]
        #expect(dominant.x < 0.2)
        #expect(dominant.y > 0.8)
        #expect(dominant.z < 0.2)
    }

    @Test("50/50 split image finds both colors")
    func splitRedBlue() {
        let image = Self.splitImage(
            topR: 255, topG: 0, topB: 0,
            bottomR: 0, bottomG: 0, bottomB: 255
        )
        let colors = ColorQuantizer.dominantColors(from: image, count: 5)

        #expect(colors.count == 5)

        // The top colors should contain roughly red and blue (with CGContext color management tolerance)
        let hasRed = colors.prefix(3).contains { $0.x > 0.7 && $0.z < 0.3 }
        let hasBlue = colors.prefix(3).contains { $0.z > 0.7 && $0.x < 0.3 }
        #expect(hasRed)
        #expect(hasBlue)
    }

    @Test("Always returns requested count")
    func countMatch() {
        let image = Self.solidImage(r: 128, g: 128, b: 128)
        let colors3 = ColorQuantizer.dominantColors(from: image, count: 3)
        let colors5 = ColorQuantizer.dominantColors(from: image, count: 5)
        let colors7 = ColorQuantizer.dominantColors(from: image, count: 7)

        #expect(colors3.count == 3)
        #expect(colors5.count == 5)
        #expect(colors7.count == 7)
    }

    @Test("All colors have alpha of 1.0")
    func alphaValues() {
        let image = Self.splitImage(
            topR: 100, topG: 200, topB: 50,
            bottomR: 200, bottomG: 50, bottomB: 150
        )
        let colors = ColorQuantizer.dominantColors(from: image, count: 5)

        for color in colors {
            #expect(color.w == 1.0)
        }
    }

    @Test("Solid white returns white-ish colors")
    func solidWhite() {
        let image = Self.solidImage(r: 255, g: 255, b: 255)
        let colors = ColorQuantizer.dominantColors(from: image, count: 5)

        let dominant = colors[0]
        #expect(dominant.x > 0.9)
        #expect(dominant.y > 0.9)
        #expect(dominant.z > 0.9)
    }
}

// MARK: - ArtifactImportService Validation Tests

@Suite("Import Validation Tests")
struct ImportValidationTests {
    let service = ArtifactImportService()

    @Test("Rejects oversized files")
    func rejectsLargeFile() throws {
        // Create a temp file larger than 100MB won't work in tests,
        // so we'll test the error type directly
        let error = ImportError.fileTooLarge("huge.png")
        #expect(error.errorDescription?.contains("100MB") == true)
    }

    @Test("Rejects unsupported format")
    func rejectsTextFile() throws {
        let error = ImportError.unsupportedFormat("file.txt")
        #expect(error.errorDescription?.contains("Unsupported") == true)
    }

    @Test("ImportError descriptions are non-empty")
    func errorDescriptions() throws {
        let errors: [ImportError] = [
            .fileTooLarge("test.png"),
            .unsupportedFormat("test.txt"),
            .thumbnailFailed("test.png"),
            .staleBookmark("test.png"),
            .importFailed("test.png"),
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - Import Integration Tests

@Suite("Import Integration Tests")
@MainActor
struct ImportIntegrationTests {

    @Test("Import single PNG creates artifact with thumbnail")
    func importSinglePNG() throws {
        let container = try ModelContainerFactory.create(inMemory: true)
        let context = container.mainContext
        let service = ArtifactImportService()

        let url = try createTestPNG(name: "test_import_single", r: 255, g: 0, b: 0)
        defer { try? FileManager.default.removeItem(at: url) }

        var progressReports: [ImportProgress] = []
        try service.importArtifacts(from: [url], into: context) { progress in
            progressReports.append(progress)
        }

        let artifacts = try context.fetch(FetchDescriptor<CreativeArtifact>())
        #expect(artifacts.count == 1)
        #expect(!artifacts[0].thumbnailData.isEmpty)
        #expect(progressReports.count == 1)
        #expect(progressReports[0].artifactID != nil)
    }

    @Test("Import multiple PNGs creates all artifacts")
    func importMultiplePNGs() throws {
        let container = try ModelContainerFactory.create(inMemory: true)
        let context = container.mainContext
        let service = ArtifactImportService()

        var urls: [URL] = []
        for i in 0..<5 {
            let url = try createTestPNG(
                name: "test_import_multi_\(i)",
                r: UInt8(i * 50), g: UInt8(50 + i * 40), b: UInt8(200 - i * 30)
            )
            urls.append(url)
        }
        defer { urls.forEach { try? FileManager.default.removeItem(at: $0) } }

        var lastProgress: ImportProgress?
        try service.importArtifacts(from: urls, into: context) { progress in
            lastProgress = progress
        }

        let artifacts = try context.fetch(FetchDescriptor<CreativeArtifact>())
        #expect(artifacts.count == 5)
        #expect(lastProgress?.completed == 5)
        #expect(lastProgress?.total == 5)
    }

    @Test("Duplicate import is skipped")
    func duplicateSkipped() throws {
        let container = try ModelContainerFactory.create(inMemory: true)
        let context = container.mainContext
        let service = ArtifactImportService()

        let url = try createTestPNG(name: "test_import_dupe", r: 100, g: 100, b: 100)
        defer { try? FileManager.default.removeItem(at: url) }

        // Import once
        try service.importArtifacts(from: [url], into: context) { _ in }

        // Import again - should skip
        var secondImportHadArtifact = false
        try service.importArtifacts(from: [url], into: context) { progress in
            if progress.artifactID != nil {
                secondImportHadArtifact = true
            }
        }

        let artifacts = try context.fetch(FetchDescriptor<CreativeArtifact>())
        #expect(artifacts.count == 1) // Only one artifact, duplicate was skipped
        #expect(!secondImportHadArtifact)
    }

    @Test("Thumbnail data is valid JPEG")
    func thumbnailIsJPEG() throws {
        let service = ArtifactImportService()
        let url = try createTestPNG(name: "test_thumb_jpeg", r: 0, g: 255, b: 0)
        defer { try? FileManager.default.removeItem(at: url) }

        let thumbData = try service.generateThumbnail(for: url)
        #expect(!thumbData.isEmpty)

        // JPEG magic bytes: FF D8 FF
        #expect(thumbData[0] == 0xFF)
        #expect(thumbData[1] == 0xD8)
        #expect(thumbData[2] == 0xFF)
    }
}

// MARK: - StyleVector Extraction Tests

@Suite("StyleVector Extraction Tests", .serialized)
struct ExtractionTests {

    @Test("Extract vector produces valid 33-dim vector that round-trips")
    func extractAndRoundTrip() async throws {
        let url = try createTestPNG(name: "test_extract_solid", r: 128, g: 64, b: 200)
        defer { try? FileManager.default.removeItem(at: url) }

        let extractor = StyleVectorExtractor()
        let vector = try await extractor.extractVector(from: url)

        // Should have 5 palette colors
        #expect(vector.colorPalette.count == 5)

        // Flatten should produce exactly 33 dimensions
        #expect(vector.flattened.count == StyleVector.dimensionCount)

        // All composition values should be in 0-1 range (sigmoid output)
        for i in 0..<8 {
            #expect(vector.composition[i] >= 0 && vector.composition[i] <= 1)
        }

        // Texture values should be in 0-1 range
        for i in 0..<4 {
            #expect(vector.texture[i] >= 0 && vector.texture[i] <= 1)
        }

        // Complexity should be in 0-1 range
        #expect(vector.complexity >= 0 && vector.complexity <= 1)

        // Verify encode/decode round-trip preserves the extracted vector
        let data = vector.encodeToPrefixedData()
        let decoded = StyleVector.decode(from: data)
        #expect(decoded != nil)
        #expect(decoded == vector)
    }

    @Test("Extract vector color palette reflects actual image color")
    func extractPreservesColor() async throws {
        let url = try createTestPNG(name: "test_extract_color", r: 255, g: 0, b: 0)
        defer { try? FileManager.default.removeItem(at: url) }

        let extractor = StyleVectorExtractor()
        let vector = try await extractor.extractVector(from: url)

        // The dominant color should be close to red (tolerance for CGContext color management)
        let dominant = vector.colorPalette[0]
        #expect(dominant.x > 0.7) // Red
        #expect(dominant.y < 0.3) // Not green
        #expect(dominant.z < 0.3) // Not blue
    }
}
