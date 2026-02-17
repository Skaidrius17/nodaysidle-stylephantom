import Foundation

struct LayoutGrid: Codable, Sendable, Equatable {
    let columns: Int
    let rows: Int
    let gutterWidth: Float
    let marginWidth: Float
    let aspectRatios: [Float]

    /// Validate grid parameters are within sane bounds
    var isValid: Bool {
        columns >= 1 && columns <= 12
            && rows >= 1 && rows <= 6
            && gutterWidth >= 0
            && marginWidth >= 0
    }

    static let `default` = LayoutGrid(
        columns: 3,
        rows: 2,
        gutterWidth: 16,
        marginWidth: 20,
        aspectRatios: Array(repeating: 1.0, count: 6)
    )
}
