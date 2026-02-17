import Foundation
import SwiftData
import simd

// MARK: - Style Trajectory

/// Represents the direction and rate of change in style evolution
struct StyleTrajectory: Sendable, Equatable {
    /// Average change between consecutive phase centroids (33-dim)
    let velocity: [Float]
    /// Rate of change of velocity (second derivative)
    let acceleration: [Float]

    static let zero = StyleTrajectory(
        velocity: Array(repeating: 0, count: StyleVector.dimensionCount),
        acceleration: Array(repeating: 0, count: StyleVector.dimensionCount)
    )
}

// MARK: - Evolution Errors

enum EvolutionError: LocalizedError, Sendable {
    case insufficientArtifacts(have: Int, need: Int)
    case missingStyleVectors

    var errorDescription: String? {
        switch self {
        case .insufficientArtifacts(let have, let need):
            "Need at least \(need) artifacts with style vectors (have \(have))"
        case .missingStyleVectors:
            "No artifacts have extracted style vectors"
        }
    }
}

// MARK: - Evolution Engine

/// Groups artifacts into aesthetic phases via k-means clustering and computes style trajectory
final class EvolutionEngine: Sendable {

    // MARK: - K-Means Clustering

    /// Run k-means clustering on flattened style vectors
    /// Returns (centroids as [[Float]], assignments as [Int] mapping each vector to its cluster)
    func kMeans(
        vectors: [[Float]],
        k: Int,
        maxIterations: Int = 100,
        tolerance: Float = 1e-6
    ) -> (centroids: [[Float]], assignments: [Int]) {
        guard !vectors.isEmpty, k > 0 else {
            return ([], [])
        }

        let dims = vectors[0].count
        let effectiveK = min(k, vectors.count)

        // Initialize centroids with k-means++ spread
        var centroids = initializeCentroids(from: vectors, k: effectiveK)
        var assignments = [Int](repeating: 0, count: vectors.count)

        for _ in 0..<maxIterations {
            // Assign each vector to nearest centroid
            var changed = false
            for i in 0..<vectors.count {
                let nearest = nearestCentroid(for: vectors[i], centroids: centroids)
                if nearest != assignments[i] {
                    assignments[i] = nearest
                    changed = true
                }
            }

            if !changed { break }

            // Recompute centroids
            var newCentroids = Array(repeating: [Float](repeating: 0, count: dims), count: effectiveK)
            var counts = [Int](repeating: 0, count: effectiveK)

            for i in 0..<vectors.count {
                let cluster = assignments[i]
                counts[cluster] += 1
                for d in 0..<dims {
                    newCentroids[cluster][d] += vectors[i][d]
                }
            }

            var maxShift: Float = 0
            for c in 0..<effectiveK {
                if counts[c] > 0 {
                    for d in 0..<dims {
                        newCentroids[c][d] /= Float(counts[c])
                    }
                }
                // Measure centroid shift
                let shift = euclideanDistance(centroids[c], newCentroids[c])
                maxShift = max(maxShift, shift)
            }

            centroids = newCentroids

            if maxShift < tolerance { break }
        }

        return (centroids, assignments)
    }

    // MARK: - Elbow Method

    /// Select optimal k by finding the maximum second derivative of the WCSS curve
    func elbowMethod(vectors: [[Float]], kRange: ClosedRange<Int> = 2...10) -> Int {
        guard vectors.count >= kRange.lowerBound else {
            return max(1, vectors.count)
        }

        let maxK = min(kRange.upperBound, vectors.count)
        let effectiveRange = kRange.lowerBound...maxK

        var wcssValues: [Float] = []

        for k in effectiveRange {
            let (centroids, assignments) = kMeans(vectors: vectors, k: k)
            let wcss = computeWCSS(vectors: vectors, centroids: centroids, assignments: assignments)
            wcssValues.append(wcss)
        }

        guard wcssValues.count >= 3 else {
            return effectiveRange.lowerBound
        }

        // Find k with maximum second derivative (sharpest elbow)
        var bestK = effectiveRange.lowerBound
        var maxSecondDeriv: Float = -.greatestFiniteMagnitude

        for i in 1..<(wcssValues.count - 1) {
            let secondDeriv = wcssValues[i - 1] - 2 * wcssValues[i] + wcssValues[i + 1]
            if secondDeriv > maxSecondDeriv {
                maxSecondDeriv = secondDeriv
                bestK = effectiveRange.lowerBound + i
            }
        }

        return bestK
    }

    // MARK: - Compute Phases

    /// Cluster artifacts into aesthetic phases
    @MainActor
    func computePhases(
        from artifacts: [CreativeArtifact],
        clusterCount: Int? = nil,
        context: ModelContext
    ) throws -> [AestheticPhase] {
        // Filter artifacts that have style vectors
        let validArtifacts = artifacts.filter { $0.styleVectorData != nil }

        guard validArtifacts.count >= 5 else {
            throw EvolutionError.insufficientArtifacts(have: validArtifacts.count, need: 5)
        }

        // Extract flattened vectors
        let vectors: [[Float]] = validArtifacts.compactMap { artifact in
            artifact.styleVector?.flattened
        }

        guard !vectors.isEmpty else {
            throw EvolutionError.missingStyleVectors
        }

        // Determine cluster count
        let k = clusterCount ?? elbowMethod(vectors: vectors)

        // Run k-means
        let (centroids, assignments) = kMeans(vectors: vectors, k: k)

        // Delete existing phases (cascade deletes projections too)
        let existingPhases = try context.fetch(FetchDescriptor<AestheticPhase>())
        for phase in existingPhases {
            context.delete(phase)
        }
        try context.save()

        // Group artifacts by cluster
        var clusterArtifacts: [Int: [CreativeArtifact]] = [:]
        for (i, cluster) in assignments.enumerated() {
            clusterArtifacts[cluster, default: []].append(validArtifacts[i])
        }

        // Create AestheticPhase records sorted by earliest import date
        var phases: [AestheticPhase] = []
        let phaseLabels = generatePhaseLabels(centroids: centroids, count: centroids.count)

        for (clusterIndex, centroid) in centroids.enumerated() {
            let clusterArts = clusterArtifacts[clusterIndex] ?? []
            guard !clusterArts.isEmpty else { continue }

            let dates = clusterArts.map { $0.importDate }
            let startDate = dates.min() ?? Date()
            let endDate = dates.max() ?? Date()

            // Create centroid StyleVector
            guard let centroidVector = StyleVector.from(flattened: centroid) else { continue }

            let phase = AestheticPhase(
                label: phaseLabels[clusterIndex],
                centroidVectorData: centroidVector.encodeToPrefixedData(),
                dateRangeStart: startDate,
                dateRangeEnd: endDate
            )
            context.insert(phase)

            // Assign artifacts to phase
            for artifact in clusterArts {
                artifact.phase = phase
            }

            phases.append(phase)
        }

        // Sort chronologically
        phases.sort { $0.dateRangeStart < $1.dateRangeStart }

        try context.save()
        return phases
    }

    // MARK: - Compute Trajectory

    /// Compute the style trajectory from chronologically-ordered phases
    func computeTrajectory(from phases: [AestheticPhase]) -> StyleTrajectory {
        let centroids: [[Float]] = phases.compactMap { $0.centroidVector?.flattened }
        guard centroids.count >= 2 else { return .zero }

        let dims = StyleVector.dimensionCount

        // Velocity: average of consecutive centroid differences
        var velocities: [[Float]] = []
        for i in 1..<centroids.count {
            var diff = [Float](repeating: 0, count: dims)
            for d in 0..<dims {
                diff[d] = centroids[i][d] - centroids[i - 1][d]
            }
            velocities.append(diff)
        }

        var avgVelocity = [Float](repeating: 0, count: dims)
        for vel in velocities {
            for d in 0..<dims {
                avgVelocity[d] += vel[d]
            }
        }
        for d in 0..<dims {
            avgVelocity[d] /= Float(velocities.count)
        }

        // Acceleration: average of consecutive velocity differences
        var avgAcceleration = [Float](repeating: 0, count: dims)
        if velocities.count >= 2 {
            var accelerations: [[Float]] = []
            for i in 1..<velocities.count {
                var diff = [Float](repeating: 0, count: dims)
                for d in 0..<dims {
                    diff[d] = velocities[i][d] - velocities[i - 1][d]
                }
                accelerations.append(diff)
            }

            for acc in accelerations {
                for d in 0..<dims {
                    avgAcceleration[d] += acc[d]
                }
            }
            for d in 0..<dims {
                avgAcceleration[d] /= Float(accelerations.count)
            }
        }

        return StyleTrajectory(velocity: avgVelocity, acceleration: avgAcceleration)
    }

    // MARK: - Private Helpers

    private func initializeCentroids(from vectors: [[Float]], k: Int) -> [[Float]] {
        guard !vectors.isEmpty else { return [] }
        guard vectors.count >= k else {
            var result = vectors
            while result.count < k {
                result.append(vectors[result.count % vectors.count])
            }
            return result
        }

        var centroids: [[Float]] = []
        centroids.append(vectors[vectors.count / 2])

        for _ in 1..<k {
            var maxDist: Float = -1
            var bestVector = vectors[0]

            for vector in vectors {
                let minDist = centroids.map { euclideanDistanceSquared(vector, $0) }.min() ?? 0
                if minDist > maxDist {
                    maxDist = minDist
                    bestVector = vector
                }
            }
            centroids.append(bestVector)
        }

        return centroids
    }

    private func nearestCentroid(for vector: [Float], centroids: [[Float]]) -> Int {
        var bestIndex = 0
        var bestDist: Float = .greatestFiniteMagnitude

        for (i, centroid) in centroids.enumerated() {
            let dist = euclideanDistanceSquared(vector, centroid)
            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }
        return bestIndex
    }

    private func euclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
        sqrt(euclideanDistanceSquared(a, b))
    }

    private func euclideanDistanceSquared(_ a: [Float], _ b: [Float]) -> Float {
        var sum: Float = 0
        let count = min(a.count, b.count)
        for i in 0..<count {
            let diff = a[i] - b[i]
            sum += diff * diff
        }
        return sum
    }

    private func computeWCSS(vectors: [[Float]], centroids: [[Float]], assignments: [Int]) -> Float {
        var wcss: Float = 0
        for (i, vector) in vectors.enumerated() {
            let cluster = assignments[i]
            if cluster < centroids.count {
                wcss += euclideanDistanceSquared(vector, centroids[cluster])
            }
        }
        return wcss
    }

    /// Generate descriptive phase labels based on centroid dominant colors
    private func generatePhaseLabels(centroids: [[Float]], count: Int) -> [String] {
        let baseNames = [
            "Minimalist", "Bold Expression", "Textured Depth",
            "Warm Harmony", "Cool Serenity", "Chromatic Burst",
            "Subtle Gradient", "High Contrast", "Organic Flow", "Geometric Precision"
        ]

        return (0..<count).map { i in
            if i < baseNames.count {
                return baseNames[i]
            }
            return "Phase \(i + 1)"
        }
    }
}
