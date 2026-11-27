import SwiftUI

// The two buttons of the Monica design system. Colours come from the asset catalog tokens, so
// they follow light and dark mode. Heights are minimums: with a large text size the label wraps
// and the button grows instead of cutting it.

/// Filled button: the main action of a screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(isEnabled ? Color.onPrimaryFill : Color.ink)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56)
            // Grey while it cannot be used, so it does not look tappable, with its label still
            // readable (a dimmed button fails the contrast audit).
            .background(isEnabled ? Color.primaryFill : Color.hairline, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Capsule())
    }
}

/// Outlined button: a secondary action next to a primary one.
struct OutlinedButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(configuration.isPressed ? Color.hairline : Color.page, in: Capsule())
            // Muted rather than the design's hairline-strong: the outline is what makes the button
            // look tappable, so it needs 3:1 against the page (hairline-strong is 1.5:1).
            .overlay(Capsule().strokeBorder(Color.muted, lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Capsule())
    }
}

/// Text button: a secondary action without a frame, such as Cancel next to Save.
struct TextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 44, minHeight: 44)
            .background(configuration.isPressed ? Color.hairline : Color.clear, in: Capsule())
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Capsule())
    }
}
