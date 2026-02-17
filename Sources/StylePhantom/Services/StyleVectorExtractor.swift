import Foundation
import Vision
import CoreGraphics
import ImageIO
import SwiftData
import simd

/// Sendable job descriptor for off-actor extraction
private struct ExtractionJob: Sendable {
    let id: UUID
    let bookmarkData: Data
}

/// Extracts 33-dimensional StyleVectors from images using Vision + ColorQuantizer
final class StyleVectorExtractor: Sendable {

    /// Extract a StyleVector from an image at the given URL
    func extractVector(from url: URL) async throws -> StyleVector {
        let colors = ColorQuantizer.dominantColors(from: url, count: 5)
        let (composition, texture, complexity) = try await extractVisionFeatures(from: url)

        return StyleVector(
            colorPalette: colors,
            composition: composition,
            texture: texture,
            complexity: complexity
        )
    }

    /// Batch-extract vectors for multiple artifacts using bounded concurrency.
    /// Must be called on @MainActor because it touches ModelContext.
    @MainActor
    func batchExtract(
        artifacts: [CreativeArtifact],
        context: ModelContext,
        concurrency: Int = 4
    ) async throws {
        // 1. Pre-read Sendable data on main actor
        let jobs: [ExtractionJob] = artifacts.compactMap { artifact in
            guard artifact.styleVectorData == nil else { return nil }
            return ExtractionJob(id: artifact.id, bookmarkData: artifact.imageBookmarkData)
        }

        guard !jobs.isEmpty else { return }

        // 2. Extract vectors off main actor via TaskGroup
        let results: [(UUID, StyleVector)] = try await withThrowingTaskGroup(of: (UUID, StyleVector?).self) { group in
            var collected: [(UUID, StyleVector)] = []
            var activeCount = 0

            for job in jobs {
                if activeCount >= concurrency {
                    if let result = try await group.next(), let vector = result.1 {
                        collected.append((result.0, vector))
                    }
                    activeCount -= 1
                }

                group.addTask {
                    do {
                        let url = try self.resolveURL(from: job.bookmarkData)
                        let didAccess = url.startAccessingSecurityScopedResource()
                        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                        let vector = try await self.extractVector(from: url)
                        return (job.id, vector)
                    } catch {
                        return (job.id, nil)
                    }
                }
                activeCount += 1
            }

            for try await result in group {
                if let vector = result.1 {
                    collected.append((result.0, vector))
                }
            }

            return collected
        }

        // 3. Apply results back on main actor
        for (id, vector) in results {
            if let artifact = artifacts.first(where: { $0.id == id }) {
                artifact.setStyleVector(vector)
            }
        }

        try context.save()
    }

    // MARK: - Vision Feature Extraction

    private func extractVisionFeatures(from url: URL) async throws -> (SIMD8<Float>, SIMD4<Float>, Float) {
        let featureVector = try await performFeaturePrint(url: url)

        let totalDims = featureVector.count
        guard totalDims > 0 else {
            return (.zero, .zero, 0)
        }

        // Composition: 8 dims from first ~60% of features (spatial/structural)
        let compositionSlice = totalDims * 60 / 100
        let compositionChunk = compositionSlice / 8
        var comp = [Float](repeating: 0, count: 8)
        for i in 0..<8 {
            let start = i * compositionChunk
            let end = min(start + compositionChunk, compositionSlice)
            if end > start {
                let slice = featureVector[start..<end]
                comp[i] = slice.reduce(0, +) / Float(slice.count)
                comp[i] = 1.0 / (1.0 + exp(-comp[i] * 3.0))
            }
        }
        let composition = SIMD8<Float>(comp[0], comp[1], comp[2], comp[3], comp[4], comp[5], comp[6], comp[7])

        // Texture: 4 dims from next ~30% of features (texture/pattern)
        let textureStart = compositionSlice
        let textureSlice = totalDims * 30 / 100
        let textureChunk = textureSlice / 4
        var tex = [Float](repeating: 0, count: 4)
        for i in 0..<4 {
            let start = textureStart + i * textureChunk
            let end = min(start + textureChunk, textureStart + textureSlice)
            if end > start {
                let slice = featureVector[start..<end]
                tex[i] = slice.reduce(0, +) / Float(slice.count)
                tex[i] = 1.0 / (1.0 + exp(-tex[i] * 3.0))
            }
        }
        let texture = SIMD4<Float>(tex[0], tex[1], tex[2], tex[3])

        // Complexity: variance of last ~10%
        let complexityStart = textureStart + textureSlice
        let complexitySlice = Array(featureVector[complexityStart...])
        let rawComplexity: Float
        if !complexitySlice.isEmpty {
            let variance = computeVariance(complexitySlice)
            rawComplexity = 1.0 / (1.0 + exp(-variance * 5.0))
        } else {
            rawComplexity = 0.5
        }

        return (composition, texture, rawComplexity)
    }

    private func performFeaturePrint(url: URL) async throws -> [Float] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observation = request.results?.first as? VNFeaturePrintObservation else {
                    continuation.resume(returning: [])
                    return
                }

                let elementCount = observation.elementCount
                var floatArray = [Float](repeating: 0, count: elementCount)
                let data = observation.data
                data.withUnsafeBytes { buffer in
                    guard let baseAddress = buffer.baseAddress else { return }
                    if observation.elementType == .float {
                        let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)
                        for i in 0..<elementCount {
                            floatArray[i] = floatBuffer[i]
                        }
                    }
                }

                continuation.resume(returning: floatArray)
            }

            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                continuation.resume(returning: [])
                return
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Helpers

    private func resolveURL(from bookmarkData: Data) throws -> URL {
        var isStale = false
        do {
            return try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            if let urlString = String(data: bookmarkData, encoding: .utf8),
               let url = URL(string: urlString) {
                return url
            }
            throw error
        }
    }

    private func computeVariance(_ values: [Float]) -> Float {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Float(values.count)
        let sumSquaredDiffs = values.reduce(Float(0)) { acc, val in
            let diff = val - mean
            return acc + diff * diff
        }
        return sumSquaredDiffs / Float(values.count)
    }
}
