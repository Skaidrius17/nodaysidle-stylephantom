import os

/// Centralized logging with categorized Loggers and signpost support
enum AppLog {
    private static let subsystem = "com.stylephantom.app"

    // MARK: - Category Loggers

    static let `import` = Logger(subsystem: subsystem, category: "import")
    static let extraction = Logger(subsystem: subsystem, category: "extraction")
    static let evolution = Logger(subsystem: subsystem, category: "evolution")
    static let projection = Logger(subsystem: subsystem, category: "projection")
    static let export = Logger(subsystem: subsystem, category: "export")
    static let sync = Logger(subsystem: subsystem, category: "sync")

    // MARK: - Signpost Support

    static let signposter = OSSignposter(subsystem: subsystem, category: "performance")

    /// Begin a signpost interval, returning the state for ending it
    static func beginInterval(_ name: StaticString) -> OSSignpostIntervalState {
        let id = signposter.makeSignpostID()
        return signposter.beginInterval(name, id: id)
    }

    /// End a signpost interval
    static func endInterval(_ name: StaticString, _ state: OSSignpostIntervalState) {
        signposter.endInterval(name, state)
    }

    /// Measure a synchronous block with a signpost interval
    static func measure<T>(_ name: StaticString, body: () throws -> T) rethrows -> T {
        let state = beginInterval(name)
        defer { endInterval(name, state) }
        return try body()
    }

    /// Measure an async block with a signpost interval
    static func measure<T>(_ name: StaticString, body: () async throws -> T) async rethrows -> T {
        let state = beginInterval(name)
        defer { endInterval(name, state) }
        return try await body()
    }
}
