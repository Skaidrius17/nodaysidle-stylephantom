import Foundation
import CoreGraphics
import ImageIO
import simd

/// Extracts dominant colors from a CGImage using k-means clustering on sampled pixels
enum ColorQuantizer: Sendable {

    /// Extract the `count` most dominant colors from an image
    /// Returns SIMD4<Float> with RGBA values normalized to 0.0-1.0
    static func dominantColors(from image: CGImage, count: Int = 5) -> [SIMD4<Float>] {
        let pixels = samplePixels(from: image, maxSamples: 5000)
        guard !pixels.isEmpty else {
            return Array(repeating: .zero, count: count)
        }

        var centroids = initializeCentroids(from: pixels, k: count)
        var assignments = [Int](repeating: 0, count: pixels.count)

        // Run k-means for up to 20 iterations
        for _ in 0..<20 {
            var changed = false

            // Assign each pixel to nearest centroid
            for i in 0..<pixels.count {
                let nearest = nearestCentroid(for: pixels[i], centroids: centroids)
                if nearest != assignments[i] {
                    assignments[i] = nearest
                    changed = true
                }
            }

            if !changed { break }

            // Recompute centroids
            var sums = Array(repeating: SIMD3<Float>.zero, count: count)
            var counts = Array(repeating: 0, count: count)

            for i in 0..<pixels.count {
                let cluster = assignments[i]
                sums[cluster] += pixels[i]
                counts[cluster] += 1
            }

            for k in 0..<count {
                if counts[k] > 0 {
                    centroids[k] = sums[k] / Float(counts[k])
                }
            }
        }

        // Count cluster sizes for sorting
        var clusterSizes = Array(repeating: 0, count: count)
        for a in assignments {
            clusterSizes[a] += 1
        }

        // Sort centroids by cluster size (largest first)
        let indexed = centroids.enumerated().map { (index: $0.offset, centroid: $0.element, size: clusterSizes[$0.offset]) }
        let sorted = indexed.sorted { $0.size > $1.size }

        return sorted.map { item in
            SIMD4<Float>(
                clamp(item.centroid.x, min: 0, max: 1),
                clamp(item.centroid.y, min: 0, max: 1),
                clamp(item.centroid.z, min: 0, max: 1),
                1.0  // Alpha
            )
        }
    }

    // MARK: - Pixel Sampling

    /// Sample pixels from CGImage by stepping through bitmap data
    private static func samplePixels(from image: CGImage, maxSamples: Int) -> [SIMD3<Float>] {
        let width = image.width
        let height = image.height
        let totalPixels = width * height
        guard totalPixels > 0 else { return [] }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return [] }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Step through pixels
        let step = max(1, totalPixels / maxSamples)
        var pixels: [SIMD3<Float>] = []
        pixels.reserveCapacity(min(maxSamples, totalPixels))

        var pixelIndex = 0
        while pixelIndex < totalPixels {
            let byteOffset = pixelIndex * bytesPerPixel
            guard byteOffset + 3 < rawData.count else { break }

            let r = Float(rawData[byteOffset]) / 255.0
            let g = Float(rawData[byteOffset + 1]) / 255.0
            let b = Float(rawData[byteOffset + 2]) / 255.0
            let a = Float(rawData[byteOffset + 3]) / 255.0

            // Skip fully transparent pixels
            if a > 0.1 {
                // Undo premultiplied alpha
                if a < 1.0 {
                    pixels.append(SIMD3(r / a, g / a, b / a))
                } else {
                    pixels.append(SIMD3(r, g, b))
                }
            }

            pixelIndex += step
        }

        return pixels
    }

    // MARK: - K-Means Helpers

    /// Initialize centroids using k-means++ style spread
    private static func initializeCentroids(from pixels: [SIMD3<Float>], k: Int) -> [SIMD3<Float>] {
        guard !pixels.isEmpty else { return Array(repeating: .zero, count: k) }
        guard pixels.count >= k else {
            var result = pixels
            while result.count < k {
                result.append(pixels[result.count % pixels.count])
            }
            return result
        }

        var centroids: [SIMD3<Float>] = []
        // Pick first centroid from middle of sorted pixels
        centroids.append(pixels[pixels.count / 2])

        for _ in 1..<k {
            // Pick point farthest from existing centroids
            var maxDist: Float = -1
            var bestPixel = pixels[0]

            for pixel in pixels {
                let minDist = centroids.map { simd_distance_squared(pixel, $0) }.min() ?? 0
                if minDist > maxDist {
                    maxDist = minDist
                    bestPixel = pixel
                }
            }
            centroids.append(bestPixel)
        }

        return centroids
    }

    /// Find index of nearest centroid to a given pixel
    private static func nearestCentroid(for pixel: SIMD3<Float>, centroids: [SIMD3<Float>]) -> Int {
        var bestIndex = 0
        var bestDist = Float.greatestFiniteMagnitude

        for (i, centroid) in centroids.enumerated() {
            let dist = simd_distance_squared(pixel, centroid)
            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }
        return bestIndex
    }

    private static func clamp(_ value: Float, min: Float, max: Float) -> Float {
        Swift.min(Swift.max(value, min), max)
    }
}

// MARK: - Convenience for URL input

extension ColorQuantizer {
    /// Extract dominant colors from an image file URL
    static func dominantColors(from url: URL, count: Int = 5) -> [SIMD4<Float>] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return Array(repeating: .zero, count: count)
        }
        return dominantColors(from: image, count: count)
    }
}
