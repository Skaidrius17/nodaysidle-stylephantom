import SwiftData

enum ModelContainerFactory {
    static func create(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: config)
    }
}
