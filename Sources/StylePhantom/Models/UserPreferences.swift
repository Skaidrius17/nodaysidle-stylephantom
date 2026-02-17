import Foundation
import SwiftData

@Model
final class UserPreferences {
    @Attribute(.unique) var id: UUID
    var defaultPaletteExportFormat: String
    var defaultLayoutExportFormat: String
    var cloudKitSyncEnabled: Bool
    var minimumArtifactThreshold: Int
    var preferredClusterCount: Int?

    init(
        id: UUID = UUID(),
        defaultPaletteExportFormat: String = "json",
        defaultLayoutExportFormat: String = "json",
        cloudKitSyncEnabled: Bool = false,
        minimumArtifactThreshold: Int = 5,
        preferredClusterCount: Int? = nil
    ) {
        self.id = id
        self.defaultPaletteExportFormat = defaultPaletteExportFormat
        self.defaultLayoutExportFormat = defaultLayoutExportFormat
        self.cloudKitSyncEnabled = cloudKitSyncEnabled
        self.minimumArtifactThreshold = minimumArtifactThreshold
        self.preferredClusterCount = preferredClusterCount
    }

    /// Singleton fetch-or-create pattern
    @MainActor
    static func shared(in context: ModelContext) -> UserPreferences {
        var descriptor = FetchDescriptor<UserPreferences>()
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let prefs = UserPreferences()
        context.insert(prefs)
        return prefs
    }
}
