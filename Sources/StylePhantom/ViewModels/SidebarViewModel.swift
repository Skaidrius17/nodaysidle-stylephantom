import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class SidebarViewModel {
    var isComputingEvolution = false
    var evolutionError: String?
    var timelinePosition: Double = 1.0  // 0.0 = earliest phase, 1.0 = latest

    private let engine = EvolutionEngine()
    private let projectionGenerator = ProjectionGenerator()

    /// Recompute evolution phases from all artifacts with style vectors
    func recomputeEvolution(context: ModelContext) async {
        isComputingEvolution = true
        evolutionError = nil

        AppLog.evolution.info("Starting evolution recomputation")
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let artifacts = try context.fetch(FetchDescriptor<CreativeArtifact>())
            AppLog.evolution.debug("Fetched \(artifacts.count) artifacts")

            let phases = try AppLog.measure("computePhases") {
                try engine.computePhases(from: artifacts, context: context)
            }
            AppLog.evolution.info("Computed \(phases.count) phases")

            if phases.count >= 2 {
                let trajectory = AppLog.measure("computeTrajectory") {
                    engine.computeTrajectory(from: phases)
                }

                _ = try AppLog.measure("generateProjection") {
                    try projectionGenerator.generateAndPersist(
                        from: phases,
                        trajectory: trajectory,
                        steps: 1,
                        context: context
                    )
                }
            }

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            AppLog.evolution.info("Evolution complete in \(String(format: "%.2f", elapsed))s")
            isComputingEvolution = false
        } catch {
            AppLog.evolution.error("Evolution failed: \(error.localizedDescription)")
            evolutionError = error.localizedDescription
            isComputingEvolution = false
        }
    }
}
