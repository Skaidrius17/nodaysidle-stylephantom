import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    @State private var isAnimating = false
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated icon with glow
            ZStack {
                // Glow backdrop
                Circle()
                    .fill(PhantomTheme.accentViolet.opacity(0.08))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)

                Image(systemName: icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(PhantomTheme.brandGradient)
                    .symbolEffect(.pulse.byLayer, options: .repeating, value: isAnimating)
            }
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: isAnimating)

            VStack(spacing: 10) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
                    .lineSpacing(3)
            }

            if let actionLabel, let action {
                Button(action: action) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body.weight(.medium))
                        Text(actionLabel)
                            .font(.body.weight(.medium))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background {
                        Capsule()
                            .fill(PhantomTheme.brandGradient)
                            .shadow(color: PhantomTheme.glowShadow, radius: isHovering ? 12 : 6)
                    }
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .scaleEffect(isHovering ? 1.03 : 1.0)
                .animation(PhantomTheme.quickSpring, value: isHovering)
                .onHover { isHovering = $0 }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { isAnimating = true }
    }
}

// MARK: - Convenience Factories

extension EmptyStateView {
    static func gallery(onImport: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "sparkles",
            title: "Begin Your Style Journey",
            subtitle: "Import your creative work to discover how your aesthetic taste has evolved over time.",
            actionLabel: "Import Artifacts",
            action: onImport
        )
    }

    static func sidebar() -> EmptyStateView {
        EmptyStateView(
            icon: "circle.hexagongrid",
            title: "No Phases Yet",
            subtitle: "Import at least 5 artifacts to detect your aesthetic evolution phases."
        )
    }

    static func detail() -> EmptyStateView {
        EmptyStateView(
            icon: "square.3.layers.3d",
            title: "Select an Artifact",
            subtitle: "Choose a piece from your gallery to explore its style dimensions."
        )
    }

    static func projection() -> EmptyStateView {
        EmptyStateView(
            icon: "arrow.triangle.branch",
            title: "No Projection Available",
            subtitle: "Compute evolution phases first to generate style projections."
        )
    }
}
