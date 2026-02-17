import Foundation
import SwiftData
import Observation
import simd

@MainActor
@Observable
final class EvolutionViewModel {
    var currentPhase: AestheticPhase?
    var projection: StyleProjection?
    var refinementFactor: Float = 0.0  // 0 = current phase, 1 = fully projected

    /// Interpolated palette between current centroid and projection
    var interpolatedPalette: [PaletteColor] {
        guard let currentVector = currentPhase?.centroidVector,
              let projVector = projection?.projectedVector else {
            if let proj = projection?.palette { return proj }
            if let phase = currentPhase?.centroidVector {
                return ProjectionGenerator().generatePalette(from: phase)
            }
            return []
        }

        let interpolated = interpolateVectors(currentVector, projVector, t: refinementFactor)
        return ProjectionGenerator().generatePalette(from: interpolated)
    }

    /// Interpolated layout grid between current and projected
    var interpolatedLayout: LayoutGrid {
        guard let currentVector = currentPhase?.centroidVector,
              let projVector = projection?.projectedVector else {
            if let layout = projection?.layout { return layout }
            if let phase = currentPhase?.centroidVector {
                return ProjectionGenerator().generateLayout(from: phase)
            }
            return .default
        }

        let interpolated = interpolateVectors(currentVector, projVector, t: refinementFactor)
        return ProjectionGenerator().generateLayout(from: interpolated)
    }

    /// Structural notes for the current interpolation state
    var structuralNotes: String {
        if refinementFactor < 0.1 {
            if let phase = currentPhase?.centroidVector {
                return ProjectionGenerator().generateStructuralNotes(from: phase)
            }
        }
        if refinementFactor > 0.9, let notes = projection?.structuralNotes {
            return notes
        }
        // Interpolated
        guard let currentVector = currentPhase?.centroidVector,
              let projVector = projection?.projectedVector else {
            return projection?.structuralNotes ?? ""
        }
        let interpolated = interpolateVectors(currentVector, projVector, t: refinementFactor)
        return ProjectionGenerator().generateStructuralNotes(from: interpolated)
    }

    /// Load data for a specific phase
    func loadPhase(_ phase: AestheticPhase) {
        currentPhase = phase
        refinementFactor = 0.0
        projection = phase.projections.first
    }

    // MARK: - Private

    private func interpolateVectors(_ a: StyleVector, _ b: StyleVector, t: Float) -> StyleVector {
        let fa = a.flattened
        let fb = b.flattened
        let dims = StyleVector.dimensionCount
        var result = [Float](repeating: 0, count: dims)
        for d in 0..<dims {
            result[d] = fa[d] * (1 - t) + fb[d] * t
        }
        return StyleVector.from(flattened: result) ?? .zero
    }
}
