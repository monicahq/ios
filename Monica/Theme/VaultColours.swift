import SwiftUI

// How a vault colour is drawn: its initial (also the form's swatch) on a tinted square. The pairs
// are measured at 4.5:1 or more in light and dark (specs/003-vaults-list/research.md, R6) and live
// in the asset catalog, under Colors/Vault.

extension VaultColour {
    /// The colour of the initial, and of the swatch in the form.
    var initialColour: Color {
        switch self {
        case .blue: .vaultBlue
        case .green: .vaultGreen
        case .ochre: .vaultOchre
        case .rust: .vaultRust
        case .violet: .vaultViolet
        case .teal: .vaultTeal
        case .rose: .vaultRose
        case .graphite: .vaultGraphite
        }
    }

    /// The square behind the initial.
    var tint: Color {
        switch self {
        case .blue: .vaultBlueTint
        case .green: .vaultGreenTint
        case .ochre: .vaultOchreTint
        case .rust: .vaultRustTint
        case .violet: .vaultVioletTint
        case .teal: .vaultTealTint
        case .rose: .vaultRoseTint
        case .graphite: .vaultGraphiteTint
        }
    }

    /// What VoiceOver says for the colour, since colour alone tells nothing to somebody who cannot
    /// see it.
    var spokenName: LocalizedStringResource {
        switch self {
        case .blue: "colour_blue"
        case .green: "colour_green"
        case .ochre: "colour_ochre"
        case .rust: "colour_rust"
        case .violet: "colour_violet"
        case .teal: "colour_teal"
        case .rose: "colour_rose"
        case .graphite: "colour_graphite"
        }
    }
}

/// The vault's initial on its tinted square. Decorative: the vault's name is read instead.
struct VaultSquare: View {
    let vault: Vault
    var size: CGFloat = 44

    @ScaledMetric(relativeTo: .headline) private var scale: CGFloat = 1

    var body: some View {
        Text(vault.initial)
            .font(.headline)
            .foregroundStyle(vault.colour.initialColour)
            .frame(width: size * scale, height: size * scale)
            .background(vault.colour.tint, in: RoundedRectangle(cornerRadius: size * scale * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }
}
