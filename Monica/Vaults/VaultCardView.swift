import SwiftUI

/// One vault, as a card: one button, read as its visible texts in order.
struct VaultCardView: View {
    let vault: Vault
    let isAccessibilitySize: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            // With the accessibility text sizes the square goes above the text, so the name keeps
            // the card's whole width.
            let layout = isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                VaultSquare(vault: vault)
                VStack(alignment: .leading, spacing: 4) {
                    Text(vault.name)
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                    Text("vault_contacts \(vault.contactCount)")
                        .font(.subheadline)
                        .foregroundStyle(Color.groupedMuted)
                    if vault.isDefault, isAccessibilitySize {
                        DefaultBadge()
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                if vault.isDefault, !isAccessibilitySize {
                    DefaultBadge()
                }
            }
            .padding(18)
            .background(Color.groupedCard, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// The badge of the vault records land in when nothing says which.
struct DefaultBadge: View {
    var body: some View {
        Text("vault_default")
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 10)
            .frame(minHeight: 24)
            .background(Color.hairline, in: Capsule())
    }
}
