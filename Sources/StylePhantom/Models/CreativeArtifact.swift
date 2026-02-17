import Foundation
import SwiftData

@Model
final class CreativeArtifact {
    @Attribute(.unique) var id: UUID
    var imageBookmarkData: Data
    var thumbnailData: Data
    var importDate: Date
    var manualTags: [String]
    var styleVectorData: Data?
    var styleVectorVersion: Int

    var phase: AestheticPhase?

    init(
        id: UUID = UUID(),
        imageBookmarkData: Data,
        thumbnailData: Data,
        importDate: Date = Date(),
        manualTags: [String] = [],
        styleVectorData: Data? = nil,
        styleVectorVersion: Int = 1
    ) {
        self.id = id
        self.imageBookmarkData = imageBookmarkData
        self.thumbnailData = thumbnailData
        self.importDate = importDate
        self.manualTags = manualTags
        self.styleVectorData = styleVectorData
        self.styleVectorVersion = styleVectorVersion
    }

    /// Decode the stored style vector from version-prefixed Data
    var styleVector: StyleVector? {
        guard let data = styleVectorData else { return nil }
        return StyleVector.decode(from: data)
    }

    /// Encode and store a StyleVector
    func setStyleVector(_ vector: StyleVector) {
        self.styleVectorData = vector.encodeToPrefixedData()
        self.styleVectorVersion = Int(StyleVector.currentVersion)
    }
}
