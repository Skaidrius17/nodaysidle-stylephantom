import SwiftData

enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CreativeArtifact.self,
            AestheticPhase.self,
            StyleProjection.self,
            UserPreferences.self,
        ]
    }
}

enum StylePhantomMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No migrations needed for V1
        []
    }
}
