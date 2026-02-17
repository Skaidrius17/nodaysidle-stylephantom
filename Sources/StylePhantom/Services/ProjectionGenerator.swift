import Foundation
import SwiftData
import simd

/// Generates future style projections from evolution trajectory
final class ProjectionGenerator: Sendable {

    // MARK: - Projection Generation

    /// Extrapolate a future StyleVector from the last phase centroid using trajectory
    func generateProjectedVector(
        from lastCentroid: StyleVector,
        trajectory: StyleTrajectory,
        steps: Int = 1
    ) -> StyleVector {
        let base = lastCentroid.flattened
        let dims = StyleVector.dimensionCount
        let t = Float(steps)

        var projected = [Float](repeating: 0, count: dims)
        for d in 0..<dims {
            // Kinematic extrapolation: pos + vel*t + 0.5*acc*t^2
            let value = base[d] + trajectory.velocity[d] * t + 0.5 * trajectory.acceleration[d] * t * t
            projected[d] = clamp(value, min: 0, max: 1)
        }

        return StyleVector.from(flattened: projected) ?? .zero
    }

    /// Compute confidence for a projection at the given step
    func confidence(atStep step: Int) -> Double {
        max(0.1, 1.0 - 0.2 * Double(step))
    }

    // MARK: - Palette Generation

    /// Generate a palette from a StyleVector's color palette
    func generatePalette(from vector: StyleVector) -> [PaletteColor] {
        vector.colorPalette.enumerated().map { (index, rgba) in
            let name = colorName(for: rgba)
            return PaletteColor.from(rgba: rgba, name: name)
        }
    }

    // MARK: - Layout Grid Generation

    /// Map composition dimensions to a layout grid
    func generateLayout(from vector: StyleVector) -> LayoutGrid {
        // composition indices: 0=thirds, 1=symmetry, 2=focal-point, 3=negative-space,
        //                     4=depth, 5=layering, 6=balance, 7=flow

        let symmetry = vector.composition[1]    // 0-1
        let negativeSpace = vector.composition[3] // 0-1
        let balance = vector.composition[6]      // 0-1
        let flow = vector.composition[7]         // 0-1

        // Symmetry -> columns (higher symmetry = more regular grid)
        let columns = Int(clamp(Float(round(symmetry * 4 + 1)), min: 1, max: 6))

        // Balance -> rows (higher balance = more rows for even distribution)
        let rows = Int(clamp(Float(round(balance * 3 + 1)), min: 1, max: 4))

        // Negative space -> gutter width (more negative space = wider gutters)
        let gutterWidth = clamp(negativeSpace * 32 + 4, min: 4, max: 40)

        // Flow -> margin width
        let marginWidth = clamp(flow * 24 + 8, min: 8, max: 32)

        // Generate aspect ratios based on composition
        let aspectRatios = (0..<(columns * rows)).map { i -> Float in
            let base: Float = 1.0
            let variation = vector.composition[i % 8] * 0.5
            return base + variation - 0.25
        }

        return LayoutGrid(
            columns: columns,
            rows: rows,
            gutterWidth: gutterWidth,
            marginWidth: marginWidth,
            aspectRatios: aspectRatios
        )
    }

    // MARK: - Structural Notes

    /// Generate compositional advice based on style vector analysis
    func generateStructuralNotes(from vector: StyleVector) -> String {
        var notes: [String] = []

        let thirds = vector.composition[0]
        let symmetry = vector.composition[1]
        let focalPoint = vector.composition[2]
        let negativeSpace = vector.composition[3]
        let depth = vector.composition[4]
        let layering = vector.composition[5]
        let balance = vector.composition[6]
        let flow = vector.composition[7]

        // Rule of thirds
        if thirds > 0.7 {
            notes.append("Strong rule-of-thirds composition. Consider placing key elements at intersection points.")
        } else if thirds < 0.3 {
            notes.append("Non-traditional framing suggests centered or edge-weighted compositions.")
        }

        // Symmetry
        if symmetry > 0.7 {
            notes.append("High symmetry detected. Mirror layouts and balanced color distributions work well.")
        } else if symmetry < 0.3 {
            notes.append("Asymmetric tendencies. Embrace off-center placements for dynamic tension.")
        }

        // Focal point
        if focalPoint > 0.7 {
            notes.append("Strong focal point preference. Use size, color, or isolation to draw the eye.")
        }

        // Negative space
        if negativeSpace > 0.6 {
            notes.append("Generous negative space. Lean into minimalism with breathing room between elements.")
        } else if negativeSpace < 0.3 {
            notes.append("Dense compositions preferred. Layer elements for richness without overcrowding.")
        }

        // Depth
        if depth > 0.6 {
            notes.append("Depth-oriented aesthetic. Use gradients, shadows, and overlapping layers.")
        }

        // Layering
        if layering > 0.6 {
            notes.append("Multi-layered approach. Stack translucent elements for visual complexity.")
        }

        // Balance
        if balance > 0.7 {
            notes.append("Strong visual balance. Distribute visual weight evenly across the composition.")
        }

        // Flow
        if flow > 0.6 {
            notes.append("Fluid visual flow. Use curved lines and organic shapes to guide the eye.")
        } else if flow < 0.3 {
            notes.append("Angular, structured flow. Grid-based layouts and sharp edges suit this direction.")
        }

        // Complexity
        if vector.complexity > 0.7 {
            notes.append("High complexity tolerance. Rich detail and intricate patterns will resonate.")
        } else if vector.complexity < 0.3 {
            notes.append("Minimalist complexity. Restrained palettes and clean geometry align with this taste.")
        }

        if notes.isEmpty {
            notes.append("Balanced composition across all dimensions. Versatile style direction.")
        }

        return notes.joined(separator: "\n")
    }

    // MARK: - Full Projection Pipeline

    /// Generate and persist a complete StyleProjection
    @MainActor
    func generateAndPersist(
        from phases: [AestheticPhase],
        trajectory: StyleTrajectory,
        steps: Int = 1,
        context: ModelContext
    ) throws -> StyleProjection? {
        guard let lastPhase = phases.last,
              let lastCentroid = lastPhase.centroidVector else {
            return nil
        }

        let projectedVector = generateProjectedVector(
            from: lastCentroid,
            trajectory: trajectory,
            steps: steps
        )

        let palette = generatePalette(from: projectedVector)
        let layout = generateLayout(from: projectedVector)
        let notes = generateStructuralNotes(from: projectedVector)
        let conf = confidence(atStep: steps)

        let paletteJSON = try JSONEncoder().encode(palette)
        let layoutJSON = try JSONEncoder().encode(layout)

        let projection = StyleProjection(
            projectedVectorData: projectedVector.encodeToPrefixedData(),
            paletteJSON: paletteJSON,
            layoutJSON: layoutJSON,
            structuralNotes: notes,
            confidence: conf
        )

        projection.sourcePhase = lastPhase
        context.insert(projection)
        try context.save()

        return projection
    }

    // MARK: - Color Naming

    /// Generate a descriptive color name from RGBA values using HSL hue
    func colorName(for rgba: SIMD4<Float>) -> String {
        let r = rgba.x, g = rgba.y, b = rgba.z

        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC

        // Lightness
        let lightness = (maxC + minC) / 2

        // Handle achromatic
        if delta < 0.05 {
            if lightness > 0.85 { return "White" }
            if lightness < 0.15 { return "Black" }
            return "Gray"
        }

        // Saturation
        let saturation: Float
        if lightness < 0.5 {
            saturation = delta / (maxC + minC)
        } else {
            saturation = delta / (2 - maxC - minC)
        }

        // Hue (0-360)
        var hue: Float
        if maxC == r {
            hue = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6))
        } else if maxC == g {
            hue = 60 * (((b - r) / delta) + 2)
        } else {
            hue = 60 * (((r - g) / delta) + 4)
        }
        if hue < 0 { hue += 360 }

        // Lightness modifier
        let lightnessPrefix: String
        if lightness > 0.75 { lightnessPrefix = "Light " }
        else if lightness < 0.25 { lightnessPrefix = "Dark " }
        else { lightnessPrefix = "" }

        // Saturation modifier
        let satPrefix: String
        if saturation < 0.25 { satPrefix = "Muted " }
        else if saturation > 0.8 { satPrefix = "Vivid " }
        else { satPrefix = "" }

        // Hue name
        let hueName: String
        switch hue {
        case 0..<15: hueName = "Red"
        case 15..<40: hueName = "Orange"
        case 40..<70: hueName = "Yellow"
        case 70..<150: hueName = "Green"
        case 150..<190: hueName = "Teal"
        case 190..<250: hueName = "Blue"
        case 250..<290: hueName = "Purple"
        case 290..<330: hueName = "Magenta"
        default: hueName = "Red"
        }

        return "\(lightnessPrefix)\(satPrefix)\(hueName)".trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Helpers

    private func clamp(_ value: Float, min: Float, max: Float) -> Float {
        Swift.min(Swift.max(value, min), max)
    }
}
