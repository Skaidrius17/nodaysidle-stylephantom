import Testing
import Foundation
import SwiftData
import simd
@testable import StylePhantom

// MARK: - K-Means Tests

@Suite("K-Means Clustering Tests")
struct KMeansTests {
    let engine = EvolutionEngine()

    /// Generate a cluster of vectors around a center point with small random offsets
    static func gaussianBlob(center: [Float], count: Int, spread: Float = 0.02) -> [[Float]] {
        (0..<count).map { i in
            center.map { val in
                let offset = Float(i % 7 - 3) * spread / 3.0
                return val + offset
            }
        }
    }

    @Test("k-means finds 3 clusters in 3-blob data")
    func threeClusters() {
        // Create 3 well-separated blobs in 33 dimensions
        let center1 = [Float](repeating: 0.1, count: 33)
        let center2 = [Float](repeating: 0.5, count: 33)
        let center3 = [Float](repeating: 0.9, count: 33)

        let vectors = Self.gaussianBlob(center: center1, count: 10)
            + Self.gaussianBlob(center: center2, count: 10)
            + Self.gaussianBlob(center: center3, count: 10)

        let (centroids, assignments) = engine.kMeans(vectors: vectors, k: 3)

        #expect(centroids.count == 3)
        #expect(assignments.count == 30)

        // All vectors in first blob should have the same assignment
        let firstBlobAssignment = assignments[0]
        for i in 0..<10 {
            #expect(assignments[i] == firstBlobAssignment)
        }

        // Clusters should be distinct
        let uniqueClusters = Set(assignments)
        #expect(uniqueClusters.count == 3)
    }

    @Test("k-means with k=1 assigns all to same cluster")
    func singleCluster() {
        let vectors = Self.gaussianBlob(center: [Float](repeating: 0.5, count: 33), count: 15)
        let (centroids, assignments) = engine.kMeans(vectors: vectors, k: 1)

        #expect(centroids.count == 1)
        #expect(Set(assignments).count == 1)
    }

    @Test("k-means with empty input returns empty")
    func emptyInput() {
        let (centroids, assignments) = engine.kMeans(vectors: [], k: 3)
        #expect(centroids.isEmpty)
        #expect(assignments.isEmpty)
    }

    @Test("k-means converges within max iterations")
    func convergence() {
        let vectors = Self.gaussianBlob(center: [Float](repeating: 0.5, count: 33), count: 20)
        let (centroids, assignments) = engine.kMeans(vectors: vectors, k: 2, maxIterations: 5)

        #expect(centroids.count == 2)
        #expect(assignments.count == 20)
    }
}

// MARK: - Elbow Method Tests

@Suite("Elbow Method Tests")
struct ElbowMethodTests {
    let engine = EvolutionEngine()

    @Test("Elbow method selects reasonable k for well-separated clusters")
    func elbowWithKnownData() {
        let center1 = [Float](repeating: 0.1, count: 33)
        let center2 = [Float](repeating: 0.5, count: 33)
        let center3 = [Float](repeating: 0.9, count: 33)

        let vectors = KMeansTests.gaussianBlob(center: center1, count: 8)
            + KMeansTests.gaussianBlob(center: center2, count: 8)
            + KMeansTests.gaussianBlob(center: center3, count: 8)

        let k = engine.elbowMethod(vectors: vectors, kRange: 2...6)

        // Should find 2-4 clusters (3 is ideal, but elbow method is approximate)
        #expect(k >= 2 && k <= 5)
    }

    @Test("Elbow method handles small data gracefully")
    func elbowSmallData() {
        let vectors = KMeansTests.gaussianBlob(center: [Float](repeating: 0.5, count: 33), count: 3)
        let k = engine.elbowMethod(vectors: vectors, kRange: 2...10)
        #expect(k >= 1 && k <= 3)
    }
}

// MARK: - Trajectory Tests

@Suite("Trajectory Tests")
struct TrajectoryTests {
    let engine = EvolutionEngine()

    /// Create a mock AestheticPhase with a specific centroid
    static func makePhase(centroid: [Float], startDate: Date, endDate: Date) -> AestheticPhase {
        guard let vector = StyleVector.from(flattened: centroid) else {
            fatalError("Invalid centroid length")
        }
        return AestheticPhase(
            label: "Test",
            centroidVectorData: vector.encodeToPrefixedData(),
            dateRangeStart: startDate,
            dateRangeEnd: endDate
        )
    }

    @Test("Linear trajectory produces constant velocity")
    func linearTrajectory() {
        // Create 3 phases with linearly increasing centroid values
        let phase1 = Self.makePhase(
            centroid: [Float](repeating: 0.2, count: 33),
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 1000)
        )
        let phase2 = Self.makePhase(
            centroid: [Float](repeating: 0.4, count: 33),
            startDate: Date(timeIntervalSince1970: 1000),
            endDate: Date(timeIntervalSince1970: 2000)
        )
        let phase3 = Self.makePhase(
            centroid: [Float](repeating: 0.6, count: 33),
            startDate: Date(timeIntervalSince1970: 2000),
            endDate: Date(timeIntervalSince1970: 3000)
        )

        let trajectory = engine.computeTrajectory(from: [phase1, phase2, phase3])

        // Velocity should be constant (0.2 per step)
        for d in 0..<33 {
            #expect(abs(trajectory.velocity[d] - 0.2) < 0.01)
        }

        // Acceleration should be zero for linear motion
        for d in 0..<33 {
            #expect(abs(trajectory.acceleration[d]) < 0.01)
        }
    }

    @Test("Accelerating trajectory has positive acceleration")
    func acceleratingTrajectory() {
        let phase1 = Self.makePhase(
            centroid: [Float](repeating: 0.1, count: 33),
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 1000)
        )
        let phase2 = Self.makePhase(
            centroid: [Float](repeating: 0.2, count: 33),
            startDate: Date(timeIntervalSince1970: 1000),
            endDate: Date(timeIntervalSince1970: 2000)
        )
        let phase3 = Self.makePhase(
            centroid: [Float](repeating: 0.5, count: 33),
            startDate: Date(timeIntervalSince1970: 2000),
            endDate: Date(timeIntervalSince1970: 3000)
        )

        let trajectory = engine.computeTrajectory(from: [phase1, phase2, phase3])

        // Velocity: avg of (0.1, 0.3) = 0.2
        #expect(abs(trajectory.velocity[0] - 0.2) < 0.01)

        // Acceleration should be positive (speeding up from 0.1 to 0.3 step)
        #expect(trajectory.acceleration[0] > 0)
    }

    @Test("Single phase returns zero trajectory")
    func singlePhase() {
        let phase = Self.makePhase(
            centroid: [Float](repeating: 0.5, count: 33),
            startDate: Date(),
            endDate: Date()
        )
        let trajectory = engine.computeTrajectory(from: [phase])
        #expect(trajectory == .zero)
    }
}

// MARK: - Projection Generator Tests

@Suite("Projection Generator Tests")
struct ProjectionGeneratorTests {
    let generator = ProjectionGenerator()

    @Test("Projection extrapolation at step 1 uses velocity")
    func projectionStep1() {
        let base = StyleVector(
            colorPalette: Array(repeating: SIMD4<Float>(0.5, 0.5, 0.5, 1.0), count: 5),
            composition: SIMD8<Float>(repeating: 0.5),
            texture: SIMD4<Float>(repeating: 0.5),
            complexity: 0.5
        )

        var velocity = [Float](repeating: 0.1, count: 33)
        let acceleration = [Float](repeating: 0, count: 33)
        // Set color palette velocity to specific values
        velocity[0] = 0.1 // R of first color

        let trajectory = StyleTrajectory(velocity: velocity, acceleration: acceleration)
        let projected = generator.generateProjectedVector(from: base, trajectory: trajectory, steps: 1)

        // R of first color should be 0.5 + 0.1 = 0.6
        #expect(abs(projected.colorPalette[0].x - 0.6) < 0.01)
    }

    @Test("Projection clamps to 0-1 range")
    func projectionClamping() {
        let base = StyleVector(
            colorPalette: Array(repeating: SIMD4<Float>(0.9, 0.1, 0.5, 1.0), count: 5),
            composition: SIMD8<Float>(repeating: 0.5),
            texture: SIMD4<Float>(repeating: 0.5),
            complexity: 0.5
        )

        let velocity = [Float](repeating: 0.3, count: 33) // Would push 0.9 to 1.2
        let trajectory = StyleTrajectory(
            velocity: velocity,
            acceleration: [Float](repeating: 0, count: 33)
        )
        let projected = generator.generateProjectedVector(from: base, trajectory: trajectory, steps: 1)

        // Should be clamped to 1.0
        #expect(projected.colorPalette[0].x <= 1.0)
        // All values should be in valid range
        for val in projected.flattened {
            #expect(val >= 0 && val <= 1)
        }
    }

    @Test("Confidence decays correctly at each step")
    func confidenceDecay() {
        #expect(abs(generator.confidence(atStep: 1) - 0.8) < 1e-10)
        #expect(abs(generator.confidence(atStep: 2) - 0.6) < 1e-10)
        #expect(abs(generator.confidence(atStep: 3) - 0.4) < 1e-10)
        #expect(abs(generator.confidence(atStep: 4) - 0.2) < 1e-10)
        #expect(abs(generator.confidence(atStep: 5) - 0.1) < 1e-10) // clamped at 0.1
        #expect(abs(generator.confidence(atStep: 10) - 0.1) < 1e-10) // still clamped
    }

    @Test("Hex conversion produces correct format")
    func hexConversion() {
        let red = PaletteColor.from(rgba: SIMD4<Float>(1.0, 0.0, 0.0, 1.0), name: "Red")
        #expect(red.hex == "#FF0000")

        let white = PaletteColor.from(rgba: SIMD4<Float>(1.0, 1.0, 1.0, 1.0), name: "White")
        #expect(white.hex == "#FFFFFF")
    }

    @Test("Color naming identifies basic hues")
    func colorNaming() {
        let redName = generator.colorName(for: SIMD4<Float>(1.0, 0.0, 0.0, 1.0))
        #expect(redName.contains("Red"))

        let blueName = generator.colorName(for: SIMD4<Float>(0.0, 0.0, 1.0, 1.0))
        #expect(blueName.contains("Blue"))

        let whiteName = generator.colorName(for: SIMD4<Float>(1.0, 1.0, 1.0, 1.0))
        #expect(whiteName == "White")

        let blackName = generator.colorName(for: SIMD4<Float>(0.0, 0.0, 0.0, 1.0))
        #expect(blackName == "Black")
    }

    @Test("Layout grid has valid bounds")
    func layoutBounds() {
        // Test with extreme composition values
        let extremeHigh = StyleVector(
            colorPalette: Array(repeating: SIMD4<Float>(1, 1, 1, 1), count: 5),
            composition: SIMD8<Float>(repeating: 1.0),
            texture: SIMD4<Float>(repeating: 1.0),
            complexity: 1.0
        )
        let layoutHigh = generator.generateLayout(from: extremeHigh)
        #expect(layoutHigh.isValid)
        #expect(layoutHigh.columns >= 1 && layoutHigh.columns <= 12)
        #expect(layoutHigh.rows >= 1 && layoutHigh.rows <= 6)

        let extremeLow = StyleVector(
            colorPalette: Array(repeating: .zero, count: 5),
            composition: SIMD8<Float>(repeating: 0.0),
            texture: SIMD4<Float>(repeating: 0.0),
            complexity: 0.0
        )
        let layoutLow = generator.generateLayout(from: extremeLow)
        #expect(layoutLow.isValid)
        #expect(layoutLow.columns >= 1)
        #expect(layoutLow.rows >= 1)
    }

    @Test("Structural notes are non-empty for any vector")
    func structuralNotes() {
        let vector = StyleVector(
            colorPalette: Array(repeating: SIMD4<Float>(0.5, 0.5, 0.5, 1.0), count: 5),
            composition: SIMD8<Float>(0.8, 0.2, 0.9, 0.1, 0.7, 0.3, 0.6, 0.4),
            texture: SIMD4<Float>(repeating: 0.5),
            complexity: 0.8
        )
        let notes = generator.generateStructuralNotes(from: vector)
        #expect(!notes.isEmpty)
        // Should mention rule-of-thirds (0.8 > 0.7 threshold)
        #expect(notes.contains("thirds"))
    }

    @Test("Palette generation produces 5 colors with names")
    func paletteGeneration() {
        let vector = StyleVector(
            colorPalette: [
                SIMD4<Float>(1.0, 0.0, 0.0, 1.0),
                SIMD4<Float>(0.0, 1.0, 0.0, 1.0),
                SIMD4<Float>(0.0, 0.0, 1.0, 1.0),
                SIMD4<Float>(1.0, 1.0, 0.0, 1.0),
                SIMD4<Float>(0.5, 0.5, 0.5, 1.0),
            ],
            composition: SIMD8<Float>(repeating: 0.5),
            texture: SIMD4<Float>(repeating: 0.5),
            complexity: 0.5
        )
        let palette = generator.generatePalette(from: vector)
        #expect(palette.count == 5)
        for color in palette {
            #expect(!color.name.isEmpty)
            #expect(color.hex.hasPrefix("#"))
            #expect(color.hex.count == 7)
        }
    }
}

// MARK: - Integration Tests

@Suite("Evolution Integration Tests")
@MainActor
struct EvolutionIntegrationTests {

    /// Create a mock artifact with a given style vector
    static func makeArtifact(vector: StyleVector, date: Date, context: ModelContext) -> CreativeArtifact {
        let artifact = CreativeArtifact(
            imageBookmarkData: Data("bookmark_\(UUID())".utf8),
            thumbnailData: Data("thumb".utf8),
            importDate: date
        )
        artifact.setStyleVector(vector)
        context.insert(artifact)
        return artifact
    }

    @Test("Full pipeline: 20 artifacts -> phases -> trajectory -> projection")
    func fullPipeline() throws {
        let container = try ModelContainerFactory.create(inMemory: true)
        let context = container.mainContext
        let engine = EvolutionEngine()
        let projector = ProjectionGenerator()

        // Create 20 artifacts across 3 style clusters
        var artifacts: [CreativeArtifact] = []
        let baseDate = Date(timeIntervalSince1970: 1_000_000)

        // Cluster 1: warm, high symmetry (7 artifacts)
        for i in 0..<7 {
            let vector = StyleVector(
                colorPalette: [
                    SIMD4<Float>(0.9, 0.3, 0.1, 1.0),
                    SIMD4<Float>(0.8, 0.4, 0.2, 1.0),
                    SIMD4<Float>(0.7, 0.2, 0.1, 1.0),
                    SIMD4<Float>(0.6, 0.3, 0.15, 1.0),
                    SIMD4<Float>(0.5, 0.2, 0.1, 1.0),
                ],
                composition: SIMD8<Float>(0.5, 0.8, 0.6, 0.3, 0.4, 0.5, 0.7, 0.6),
                texture: SIMD4<Float>(0.3, 0.4, 0.5, 0.2),
                complexity: 0.4
            )
            let date = baseDate.addingTimeInterval(Double(i) * 86400)
            artifacts.append(Self.makeArtifact(vector: vector, date: date, context: context))
        }

        // Cluster 2: cool, asymmetric (7 artifacts)
        for i in 0..<7 {
            let vector = StyleVector(
                colorPalette: [
                    SIMD4<Float>(0.1, 0.3, 0.9, 1.0),
                    SIMD4<Float>(0.2, 0.4, 0.8, 1.0),
                    SIMD4<Float>(0.1, 0.2, 0.7, 1.0),
                    SIMD4<Float>(0.15, 0.3, 0.6, 1.0),
                    SIMD4<Float>(0.1, 0.2, 0.5, 1.0),
                ],
                composition: SIMD8<Float>(0.3, 0.2, 0.4, 0.7, 0.6, 0.3, 0.3, 0.2),
                texture: SIMD4<Float>(0.7, 0.6, 0.8, 0.5),
                complexity: 0.7
            )
            let date = baseDate.addingTimeInterval(Double(7 + i) * 86400)
            artifacts.append(Self.makeArtifact(vector: vector, date: date, context: context))
        }

        // Cluster 3: neutral, balanced (6 artifacts)
        for i in 0..<6 {
            let vector = StyleVector(
                colorPalette: [
                    SIMD4<Float>(0.5, 0.5, 0.5, 1.0),
                    SIMD4<Float>(0.4, 0.4, 0.4, 1.0),
                    SIMD4<Float>(0.6, 0.6, 0.6, 1.0),
                    SIMD4<Float>(0.45, 0.45, 0.45, 1.0),
                    SIMD4<Float>(0.55, 0.55, 0.55, 1.0),
                ],
                composition: SIMD8<Float>(0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5),
                texture: SIMD4<Float>(0.5, 0.5, 0.5, 0.5),
                complexity: 0.5
            )
            let date = baseDate.addingTimeInterval(Double(14 + i) * 86400)
            artifacts.append(Self.makeArtifact(vector: vector, date: date, context: context))
        }

        try context.save()

        // Compute phases
        let phases = try engine.computePhases(from: artifacts, context: context)
        #expect(phases.count >= 2)
        #expect(phases.count <= 5)

        // Verify all artifacts are assigned to phases
        let allAssigned = artifacts.allSatisfy { $0.phase != nil }
        #expect(allAssigned)

        // Compute trajectory
        let trajectory = engine.computeTrajectory(from: phases)
        #expect(trajectory.velocity.count == 33)
        #expect(trajectory.acceleration.count == 33)

        // Generate projection
        let projection = try projector.generateAndPersist(
            from: phases,
            trajectory: trajectory,
            steps: 1,
            context: context
        )
        #expect(projection != nil)
        #expect(projection?.palette?.count == 5)
        #expect(projection?.layout != nil)
        #expect(projection?.layout?.isValid == true)
        #expect(!projection!.structuralNotes.isEmpty)
        #expect(projection!.confidence == 0.8)
        #expect(projection?.sourcePhase != nil)
    }

    @Test("Insufficient artifacts throws error")
    func insufficientArtifacts() throws {
        let container = try ModelContainerFactory.create(inMemory: true)
        let context = container.mainContext
        let engine = EvolutionEngine()

        // Only 3 artifacts (need 5)
        let vector = StyleVectorTests.sample
        for i in 0..<3 {
            let artifact = CreativeArtifact(
                imageBookmarkData: Data("bm\(i)".utf8),
                thumbnailData: Data("t".utf8)
            )
            artifact.setStyleVector(vector)
            context.insert(artifact)
        }
        try context.save()

        let artifacts = try context.fetch(FetchDescriptor<CreativeArtifact>())

        #expect(throws: EvolutionError.self) {
            try engine.computePhases(from: artifacts, context: context)
        }
    }
}
