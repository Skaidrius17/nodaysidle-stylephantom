import Foundation
import SwiftData

@Model
final class StyleProjection {
    @Attribute(.unique) var id: UUID
    var projectedVectorData: Data
    var paletteJSON: Data
    var layoutJSON: Data
    var structuralNotes: String
    var confidence: Double
    var creationDate: Date

    var sourcePhase: AestheticPhase?

    init(
        id: UUID = UUID(),
        projectedVectorData: Data,
        paletteJSON: Data,
        layoutJSON: Data,
        structuralNotes: String,
        confidence: Double,
        creationDate: Date = Date()
    ) {
        self.id = id
        self.projectedVectorData = projectedVectorData
        self.paletteJSON = paletteJSON
        self.layoutJSON = layoutJSON
        self.structuralNotes = structuralNotes
        self.confidence = confidence
        self.creationDate = creationDate
    }

    /// Decode projected style vector
    var projectedVector: StyleVector? {
        StyleVector.decode(from: projectedVectorData)
    }

    /// Decode palette from stored JSON
    var palette: [PaletteColor]? {
        try? JSONDecoder().decode([PaletteColor].self, from: paletteJSON)
    }

    /// Decode layout grid from stored JSON
    var layout: LayoutGrid? {
        try? JSONDecoder().decode(LayoutGrid.self, from: layoutJSON)
    }

    /// Confidence as a percentage string
    var confidenceFormatted: String {
        "\(Int(confidence * 100))%"
    }
}
