import Foundation
import SwiftData

@Model
final class AestheticPhase {
    @Attribute(.unique) var id: UUID
    var label: String
    var centroidVectorData: Data
    var dateRangeStart: Date
    var dateRangeEnd: Date

    @Relationship(deleteRule: .nullify, inverse: \CreativeArtifact.phase)
    var artifacts: [CreativeArtifact] = []

    @Relationship(deleteRule: .cascade, inverse: \StyleProjection.sourcePhase)
    var projections: [StyleProjection] = []

    init(
        id: UUID = UUID(),
        label: String,
        centroidVectorData: Data,
        dateRangeStart: Date,
        dateRangeEnd: Date
    ) {
        self.id = id
        self.label = label
        self.centroidVectorData = centroidVectorData
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
    }

    /// Decode centroid vector from stored Data
    var centroidVector: StyleVector? {
        StyleVector.decode(from: centroidVectorData)
    }

    /// The dominant color from the centroid for UI display
    var dominantColor: (r: Float, g: Float, b: Float) {
        guard let vector = centroidVector, let first = vector.colorPalette.first else {
            return (r: 0.5, g: 0.4, b: 0.8)
        }
        return (r: first.x, g: first.y, b: first.z)
    }

    /// Formatted date range string for display
    var dateRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "\(formatter.string(from: dateRangeStart)) - \(formatter.string(from: dateRangeEnd))"
    }
}
