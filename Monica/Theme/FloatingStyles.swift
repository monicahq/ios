import SwiftUI

// The two controls that float over the list of vaults, drawn in Liquid Glass as in the design.
// Each has three looks (specs/003-vaults-list/research.md, R8):
// - iOS 26 and later: the system's glass;
// - earlier versions: the standard material, or a solid fill for the dark button;
// - Reduce Transparency on: solid, whatever the version, so nothing behind can blur the text.

/// UI tests ask for solid controls with `MONICA_UI_TEST_REDUCE_TRANSPARENCY` (Debug builds only),
/// since a test cannot change the simulator's setting.
private let reduceTransparencyForUITests: Bool = {
    #if DEBUG
        ProcessInfo.processInfo.environment["MONICA_UI_TEST_REDUCE_TRANSPARENCY"] == "1"
    #else
        false
    #endif
}()

extension View {
    /// The round account button's background.
    func floatingCircle() -> some View {
        modifier(FloatingCircle())
    }

    /// The "New vault" capsule: the screen's main action, floating at the bottom.
    func floatingPrimaryButton() -> some View {
        modifier(FloatingPrimaryButton())
    }
}

private struct FloatingCircle: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency || reduceTransparencyForUITests {
            content
                .background(Color.groupedCard, in: Circle())
                .overlay(Circle().strokeBorder(Color.hairlineStrong, lineWidth: 1))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .circle)
        } else {
            content.background(.regularMaterial, in: Circle())
        }
    }
}

private struct FloatingPrimaryButton: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let solid = reduceTransparency || reduceTransparencyForUITests
        if !solid, #available(iOS 26.0, *) {
            content.buttonStyle(.glassProminent).tint(Color.primaryFill)
        } else {
            content.buttonStyle(FloatingCapsuleButtonStyle(hasShadow: !solid))
        }
    }
}

/// "New vault" before glass, or with Reduce Transparency: a solid capsule in the primary colour.
private struct FloatingCapsuleButtonStyle: ButtonStyle {
    let hasShadow: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.onPrimaryFill)
            .background(Color.primaryFill, in: Capsule())
            .shadow(color: .black.opacity(hasShadow ? 0.2 : 0), radius: 15, y: 10)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Capsule())
    }
}
