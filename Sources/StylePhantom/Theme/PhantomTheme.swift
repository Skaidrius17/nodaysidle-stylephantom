import SwiftUI

// MARK: - Design System

enum PhantomTheme {
    // MARK: Accent Colors
    static let accentViolet = Color(hue: 0.74, saturation: 0.65, brightness: 0.95)
    static let accentCoral = Color(hue: 0.97, saturation: 0.55, brightness: 1.0)
    static let accentIndigo = Color(hue: 0.70, saturation: 0.50, brightness: 0.85)

    // MARK: Gradients
    static let brandGradient = LinearGradient(
        colors: [accentViolet, accentCoral],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let subtleGradient = LinearGradient(
        colors: [accentViolet.opacity(0.3), accentCoral.opacity(0.15)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let surfaceGradient = LinearGradient(
        colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: Spacing
    static let cornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 10
    static let spacing: CGFloat = 16
    static let compactSpacing: CGFloat = 8

    // MARK: Shadows
    static let cardShadow: Color = .black.opacity(0.25)
    static let glowShadow: Color = accentViolet.opacity(0.3)

    // MARK: Animation
    static let springAnimation = Animation.spring(response: 0.4, dampingFraction: 0.75)
    static let quickSpring = Animation.spring(response: 0.25, dampingFraction: 0.8)
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - View Modifiers

struct PhantomCardStyle: ViewModifier {
    var isSelected: Bool = false
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: PhantomTheme.cardCornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: PhantomTheme.cardCornerRadius)
                            .strokeBorder(
                                isSelected
                                    ? PhantomTheme.accentViolet.opacity(0.6)
                                    : Color.white.opacity(isHovered ? 0.12 : 0.06),
                                lineWidth: 1
                            )
                    }
            }
            .shadow(color: isSelected ? PhantomTheme.glowShadow : .clear, radius: 8)
            .shadow(color: PhantomTheme.cardShadow, radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
    }
}

struct GradientTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(PhantomTheme.brandGradient)
    }
}

extension View {
    func phantomCard(isSelected: Bool = false, isHovered: Bool = false) -> some View {
        modifier(PhantomCardStyle(isSelected: isSelected, isHovered: isHovered))
    }

    func gradientText() -> some View {
        modifier(GradientTextStyle())
    }
}
