import SwiftUI

// MARK: - Z-Index

enum ZLayer {
    static let video: Double = 0
    static let scrim: Double = 10
    static let scrimCC: Double = 15
    static let glassPanel: Double = 20
    static let capsule: Double = 30
    static let player: Double = 40
}

// MARK: - Panel Sizes

enum PanelSize {
    static let leftPanel: CGFloat = 220
    static let queuePanel: CGFloat = 220
    static let playerHeight: CGFloat = 44
    static let hitArea: CGFloat = 44
    static let primaryHitArea: CGFloat = 44
}

// MARK: - Spacing (8pt grid)

enum Spacing {
    static let micro: CGFloat = 4
    static let tight: CGFloat = 8
    static let medium: CGFloat = 12
    static let wide: CGFloat = 16
    static let macro: CGFloat = 24
    static let huge: CGFloat = 32
}

// MARK: - Radii

enum Radius {
    static let capsule: CGFloat = 14
    static let panel: CGFloat = 10
    static let panelInner: CGFloat = 8
    static let button: CGFloat = 6
}

// MARK: - Glass UI Colors

extension Color {
    static let glassForeground: Color = .white
    static let glassForegroundSecondary: Color = .white.opacity(0.65)
    static let glassForegroundTertiary: Color = .white.opacity(0.35)
    static let glassHighlight: Color = .white.opacity(0.12)
    static let accentGlass: Color = .white.opacity(0.85)
    static let favoriteActive: Color = .pink
}

// MARK: - Scrim

extension ShapeStyle where Self == LinearGradient {
    static var scrimTop: LinearGradient {
        LinearGradient(
            colors: [.black.opacity(0.5), .clear],
            startPoint: .top, endPoint: .bottom
        )
    }

    static var scrimBottom: LinearGradient {
        LinearGradient(
            colors: [.clear, .black.opacity(0.4)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Press Feedback

struct PressFeedback: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Typography

enum AppFont {
    static let body: Font = .system(size: 13)
    static let caption: Font = .system(size: 11)
    static let small: Font = .system(size: 10)
    static let title: Font = .system(size: 15, weight: .medium)
    static let largeIcon: Font = .system(size: 18)
    static let mediumIcon: Font = .system(size: 14)
    static let smallIcon: Font = .system(size: 12)
}
