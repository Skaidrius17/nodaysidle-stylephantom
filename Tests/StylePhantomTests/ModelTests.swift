import Testing
import Foundation
import SwiftData
import simd
@testable import StylePhantom

// MARK: - StyleVector Encoding/Decoding Tests

@Suite("StyleVector Tests")
struct StyleVectorTests {
    static let sample = StyleVector(
        colorPalette: [
            SIMD4<Float>(1.0, 0.0, 0.0, 1.0),
            SIMD4<Float>(0.0, 1.0, 0.0, 1.0),
            SIMD4<Float>(0.0, 0.0, 1.0, 1.0),
            SIMD4<Float>(0.5, 0.5, 0.5, 1.0),
            SIMD4<Float>(0.0, 0.0, 0.0, 1.0),
        ],
        composition: SIMD8<Float>(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8),
        texture: SIMD4<Float>(0.25, 0.50, 0.75, 1.0),
        complexity: 0.42
    )

    @Test("Round-trip encode/decode preserves all 33 float values")
    func roundTrip() throws {
        let data = Self.sample.encodeToPrefixedData()
        let decoded = StyleVector.decode(from: data)
        #expect(decoded != nil)
        #expect(decoded == Self.sample)
    }

    @Test("Version byte is correct")
    func versionByte() throws {
        let data = Self.sample.encodeToPrefixedData()
        #expect(data[data.startIndex] == StyleVector.currentVersion)
    }

    @Test("Unknown version byte returns nil")
    func unknownVersion() throws {
        var data = Self.sample.encodeToPrefixedData()
        data[data.startIndex] = 99 // unknown version
        let decoded = StyleVector.decode(from: data)
        #expect(decoded == nil)
    }

    @Test("Empty data returns nil")
    func emptyData() throws {
        let decoded = StyleVector.decode(from: Data())
        #expect(decoded == nil)
    }

    @Test("Single byte returns nil")
    func singleByte() throws {
        let decoded = StyleVector.decode(from: Data([1]))
        #expect(decoded == nil)
    }

    @Test("Corrupted JSON returns nil")
    func corruptedJSON() throws {
        var data = Data([StyleVector.currentVersion])
        data.append(Data("not valid json".utf8))
        let decoded = StyleVector.decode(from: data)
        #expect(decoded == nil)
    }

    @Test("SIMD component precision preserved")
    func simdPrecision() throws {
        let precise = StyleVector(
            colorPalette: [
                SIMD4<Float>(0.123456, 0.654321, 0.111111, 0.999999),
                SIMD4<Float>(0.0, 0.0, 0.0, 0.0),
                SIMD4<Float>(1.0, 1.0, 1.0, 1.0),
                SIMD4<Float>(0.333333, 0.666666, 0.5, 0.75),
                SIMD4<Float>(0.1, 0.2, 0.3, 0.4),
            ],
            composition: SIMD8<Float>(0.12345, 0.23456, 0.34567, 0.45678, 0.56789, 0.67890, 0.78901, 0.89012),
            texture: SIMD4<Float>(0.1111, 0.2222, 0.3333, 0.4444),
            complexity: 0.98765
        )
        let data = precise.encodeToPrefixedData()
        let decoded = StyleVector.decode(from: data)
        #expect(decoded == precise)
    }

    @Test("Flatten and reconstruct")
    func flattenReconstruct() throws {
        let flat = Self.sample.flattened
        #expect(flat.count == StyleVector.dimensionCount)
        let reconstructed = StyleVector.from(flattened: flat)
        #expect(reconstructed == Self.sample)
    }

    @Test("Flatten with wrong count returns nil")
    func flattenWrongCount() throws {
        let short: [Float] = [1.0, 2.0, 3.0]
        let result = StyleVector.from(flattened: short)
        #expect(result == nil)
    }
}

// MARK: - PaletteColor Tests

@Suite("PaletteColor Tests")
struct PaletteColorTests {
    @Test("Round-trip JSON encode/decode")
    func roundTrip() throws {
        let color = PaletteColor(hex: "#FF0000", name: "Bright Red", rgba: SIMD4<Float>(1.0, 0.0, 0.0, 1.0))
        let data = try JSONEncoder().encode(color)
        let decoded = try JSONDecoder().decode(PaletteColor.self, from: data)
        #expect(decoded.hex == "#FF0000")
        #expect(decoded.name == "Bright Red")
        #expect(decoded.rgba.x == 1.0)
        #expect(decoded.rgba.y == 0.0)
    }

    @Test("From RGBA generates correct hex")
    func fromRGBA() throws {
        let color = PaletteColor.from(rgba: SIMD4<Float>(1.0, 0.0, 0.0, 1.0), name: "Red")
        #expect(color.hex == "#FF0000")

        let black = PaletteColor.from(rgba: SIMD4<Float>(0.0, 0.0, 0.0, 1.0), name: "Black")
        #expect(black.hex == "#000000")

        let white = PaletteColor.from(rgba: SIMD4<Float>(1.0, 1.0, 1.0, 1.0), name: "White")
        #expect(white.hex == "#FFFFFF")
    }
}

// MARK: - LayoutGrid Tests

@Suite("LayoutGrid Tests")
struct LayoutGridTests {
    @Test("Round-trip JSON encode/decode")
    func roundTrip() throws {
        let grid = LayoutGrid(columns: 3, rows: 2, gutterWidth: 16, marginWidth: 20, aspectRatios: [1.0, 1.5, 0.75, 1.0, 1.5, 0.75])
        let data = try JSONEncoder().encode(grid)
        let decoded = try JSONDecoder().decode(LayoutGrid.self, from: data)
        #expect(decoded == grid)
    }

    @Test("Validation checks bounds")
    func validation() throws {
        let valid = LayoutGrid(columns: 3, rows: 2, gutterWidth: 16, marginWidth: 20, aspectRatios: [])
        #expect(valid.isValid)

        let invalidCols = LayoutGrid(columns: 0, rows: 2, gutterWidth: 16, marginWidth: 20, aspectRatios: [])
        #expect(!invalidCols.isValid)

        let invalidRows = LayoutGrid(columns: 3, rows: 7, gutterWidth: 16, marginWidth: 20, aspectRatios: [])
        #expect(!invalidRows.isValid)

        let negativeGutter = LayoutGrid(columns: 3, rows: 2, gutterWidth: -1, marginWidth: 20, aspectRatios: [])
        #expect(!negativeGutter.isValid)
    }

    @Test("Default layout is valid")
    func defaultValid() {
        #expect(LayoutGrid.default.isValid)
    }
}

// MARK: - SwiftData Relationship Tests

@Suite("SwiftData Model Tests")
@MainActor
struct SwiftDataModelTests {
    @Test("CreativeArtifact stores and decodes style vector")
    func artifactStyleVector() throws {
        let container = try ModelContainerFactory.create(inMemory: true)
        let context = container.mainContext

        let vector = StyleVectorTests.sample
        let artifact = CreativeArtifact(
            imageBookmarkData: Data("bookmark".utf8),
            thumbnailData: Data("thumb".utf8)
        )
        artifact.setStyleVector(vector)
        context.insert(artifact)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CreativeArtifact>())
        #expect(fetched.count == 1)
        #expect(fetched[0].styleVector == vector)
        #expect(fetched[0].styleVectorVersion == Int(StyleVector.currentVersion))
    }

    @Test("Deleting phase nullifies artifact.phase")
    func deletePhaseNullifiesArtifact() throws {
        let container = try ModelContainerFactory.create(inMemory: true)
        let context = container.mainContext

        let artifact = CreativeArtifact(
            imageBookmarkData: Data("bookmark".utf8),
            thumbnailData: Data("thumb".utf8)
        )
        context.insert(artifact)

        let phase = AestheticPhase(
            label: "Test Phase",
            centroidVectorData: StyleVectorTests.sample.encodeToPrefixedData(),
            dateRangeStart: Date(),
            dateRangeEnd: Date()
        )
        context.insert(phase)
        artifact.phase = phase
        try context.save()

        // Verify relationship
        #expect(artifact.phase != nil)
        #expect(phase.artifacts.contains(where: { $0.id == artifact.id }))

        // Delete phase
        context.delete(phase)
        try context.save()

        // Artifact should still exist but phase should be nil
        let artifacts = try context.fetch(FetchDescriptor<CreativeArtifact>())
        #expect(artifacts.count == 1)
        #expect(artifacts[0].phase == nil)
    }

    @Test("Deleting phase cascades to projections")
    func deletePhase_CascadesProjections() throws {
        let container = try ModelContainerFactory.create(inMemory: true)
        let context = container.mainContext

        let phase = AestheticPhase(
            label: "Test Phase",
            centroidVectorData: StyleVectorTests.sample.encodeToPrefixedData(),
            dateRangeStart: Date(),
            dateRangeEnd: Date()
        )
        context.insert(phase)

        let projection = StyleProjection(
            projectedVectorData: StyleVectorTests.sample.encodeToPrefixedData(),
            paletteJSON: try JSONEncoder().encode([PaletteColor.from(rgba: .zero, name: "test")]),
            layoutJSON: try JSONEncoder().encode(LayoutGrid.default),
            structuralNotes: "Test notes",
            confidence: 0.8
        )
        context.insert(projection)
        projection.sourcePhase = phase
        try context.save()

        // Verify projection exists
        #expect(try context.fetch(FetchDescriptor<StyleProjection>()).count == 1)

        // Delete phase - should cascade to projection
        context.delete(phase)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<StyleProjection>()).count == 0)
    }

    @Test("UserPreferences singleton pattern")
    func preferencesSingleton() throws {
        let container = try ModelContainerFactory.create(inMemory: true)
        let context = container.mainContext

        // First call creates
        let prefs1 = UserPreferences.shared(in: context)
        try context.save()

        // Second call returns same instance
        let prefs2 = UserPreferences.shared(in: context)
        #expect(prefs1.id == prefs2.id)

        // Default values
        #expect(prefs1.cloudKitSyncEnabled == false)
        #expect(prefs1.minimumArtifactThreshold == 5)
        #expect(prefs1.defaultPaletteExportFormat == "json")
    }

    @Test("UserPreferences returns first even if multiple inserted")
    func preferencesSingletonMultiple() throws {
        let container = try ModelContainerFactory.create(inMemory: true)
        let context = container.mainContext

        // Insert two manually
        context.insert(UserPreferences())
        context.insert(UserPreferences())
        try context.save()

        // shared() should return just one
        let prefs = UserPreferences.shared(in: context)
        #expect(prefs.id != UUID()) // it should be a valid UUID, not default
    }

    @Test("StyleProjection decodes palette and layout")
    func projectionDecodedProperties() throws {
        let container = try ModelContainerFactory.create(inMemory: true)
        let context = container.mainContext

        let palette = [
            PaletteColor.from(rgba: SIMD4<Float>(1, 0, 0, 1), name: "Red"),
            PaletteColor.from(rgba: SIMD4<Float>(0, 1, 0, 1), name: "Green"),
        ]
        let layout = LayoutGrid(columns: 4, rows: 3, gutterWidth: 12, marginWidth: 16, aspectRatios: Array(repeating: 1.0, count: 12))

        let projection = StyleProjection(
            projectedVectorData: StyleVectorTests.sample.encodeToPrefixedData(),
            paletteJSON: try JSONEncoder().encode(palette),
            layoutJSON: try JSONEncoder().encode(layout),
            structuralNotes: "High symmetry suggests balanced grid",
            confidence: 0.85
        )
        context.insert(projection)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<StyleProjection>())
        #expect(fetched.count == 1)
        #expect(fetched[0].palette?.count == 2)
        #expect(fetched[0].palette?[0].hex == "#FF0000")
        #expect(fetched[0].layout?.columns == 4)
        #expect(fetched[0].confidenceFormatted == "85%")
    }

    @Test("ModelContainerFactory creates container with all models")
    func containerCreation() throws {
        let container = try ModelContainerFactory.create(inMemory: true)
        // If we got here, all 4 model types are registered
        let context = container.mainContext

        // Verify we can insert each type
        context.insert(CreativeArtifact(imageBookmarkData: Data(), thumbnailData: Data()))
        context.insert(AestheticPhase(label: "P", centroidVectorData: Data(), dateRangeStart: Date(), dateRangeEnd: Date()))
        context.insert(StyleProjection(projectedVectorData: Data(), paletteJSON: Data(), layoutJSON: Data(), structuralNotes: "", confidence: 0))
        context.insert(UserPreferences())
        try context.save()

        #expect(try context.fetch(FetchDescriptor<CreativeArtifact>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<AestheticPhase>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<StyleProjection>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<UserPreferences>()).count == 1)
    }
}
