import SwiftUI
import SwiftData

struct TimelineScrubberView: View {
    @Query(sort: \AestheticPhase.dateRangeStart) private var phases: [AestheticPhase]
    @Binding var selectedPhase: AestheticPhase?
    @Binding var timelinePosition: Double

    @State private var isDragging = false
    @State private var animationTime: Double = 0

    private let scrubberHeight: CGFloat = 56

    var body: some View {
        if phases.count >= 2 {
            VStack(spacing: 0) {
                Divider()

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Gradient background using Metal shader
                        timelineBackground(size: geo.size)

                        // Phase markers
                        phaseMarkers(in: geo.size)

                        // Scrubber handle
                        scrubberHandle(in: geo.size)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let pos = max(0, min(1, value.location.x / geo.size.width))
                                timelinePosition = pos

                                // Snap to nearest phase
                                let nearestIndex = Int(round(pos * Double(phases.count - 1)))
                                if nearestIndex >= 0 && nearestIndex < phases.count {
                                    selectedPhase = phases[nearestIndex]
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                }
                .frame(height: scrubberHeight)
                .clipShape(RoundedRectangle(cornerRadius: 0))

                // Phase labels
                phaseLabels
            }
            .onAppear {
                // Set initial position to last phase
                if selectedPhase == nil, let last = phases.last {
                    selectedPhase = last
                    timelinePosition = 1.0
                }
            }
        }
    }

    // MARK: - Timeline Background

    private func timelineBackground(size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate

            Canvas { ctx, canvasSize in
                // Draw phase bands manually as a fallback
                let bandWidth = canvasSize.width / CGFloat(max(1, phases.count))

                for (i, phase) in phases.enumerated() {
                    let dc = phase.dominantColor
                    let color = Color(red: Double(dc.r), green: Double(dc.g), blue: Double(dc.b))

                    let x = bandWidth * CGFloat(i)
                    let rect = CGRect(x: x, y: 0, width: bandWidth, height: canvasSize.height)

                    // Blend with neighbors via opacity gradient
                    let shimmer = 0.85 + 0.15 * sin(Double(i) * 1.5 + t * 0.8)
                    ctx.opacity = shimmer

                    ctx.fill(Path(rect), with: .color(color.opacity(0.6)))

                    // Vertical gradient overlay for depth
                    let gradient = Gradient(colors: [
                        .white.opacity(0.1),
                        .clear,
                        .black.opacity(0.15)
                    ])
                    ctx.fill(
                        Path(rect),
                        with: .linearGradient(gradient, startPoint: .init(x: x, y: 0), endPoint: .init(x: x, y: canvasSize.height))
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Phase Markers

    private func phaseMarkers(in size: CGSize) -> some View {
        ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
            let x = phases.count > 1
                ? CGFloat(index) / CGFloat(phases.count - 1) * size.width
                : size.width * 0.5

            Circle()
                .fill(selectedPhase?.id == phase.id ? PhantomTheme.accentViolet : .white.opacity(0.7))
                .frame(width: selectedPhase?.id == phase.id ? 10 : 7, height: selectedPhase?.id == phase.id ? 10 : 7)
                .shadow(color: .black.opacity(0.3), radius: 2)
                .position(x: x, y: size.height / 2)
                .animation(PhantomTheme.quickSpring, value: selectedPhase?.id)
        }
    }

    // MARK: - Scrubber Handle

    private func scrubberHandle(in size: CGSize) -> some View {
        let x = timelinePosition * size.width

        return RoundedRectangle(cornerRadius: 2)
            .fill(.white)
            .frame(width: 3, height: size.height - 8)
            .shadow(color: PhantomTheme.accentViolet.opacity(isDragging ? 0.6 : 0.3), radius: isDragging ? 8 : 4)
            .position(x: x, y: size.height / 2)
            .animation(isDragging ? nil : PhantomTheme.quickSpring, value: timelinePosition)
    }

    // MARK: - Phase Labels

    private var phaseLabels: some View {
        HStack {
            ForEach(phases) { phase in
                Text(phase.label)
                    .font(.system(size: 9))
                    .foregroundStyle(selectedPhase?.id == phase.id ? .primary : .tertiary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
    }
}
