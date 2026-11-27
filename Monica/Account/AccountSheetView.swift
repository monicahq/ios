import SwiftUI

/// The account of the signed-in person, opened from the list of vaults: who is signed in, on which
/// instance, and the ways out. Stateless.
///
/// Laid out as the instance sheet (opaque background, its own Close button), since a system bar
/// over the iOS 26 sheet glass fails the accessibility audit. The instance sheet opens over it.
struct AccountSheetView: View {
    let state: AccountUiState
    let onClose: () -> Void
    let onLogOut: () -> Void
    let onConfirmLogOut: () -> Void
    let onCancelLogOut: () -> Void
    let onOpenInstanceSheet: () -> Void
    let onDraftChange: (String) -> Void
    let onResetDraft: () -> Void
    let onDismissInstanceSheet: () -> Void
    let onSaveInstance: () -> Void
    let onConfirmSwitch: (String) -> Void
    let onCancelSwitch: () -> Void

    private var title: String {
        state.name.isEmpty ? String(localized: "account_button") : state.name
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button("account_close", action: onClose)
                    .buttonStyle(TextButtonStyle())
                    .padding(.leading, -12)
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Button(action: onOpenInstanceSheet) {
                    HStack(spacing: 8) {
                        Image(systemName: "server.rack")
                            .accessibilityHidden(true)
                        Text(String(format: String(localized: "account_connected"), instanceHost(state.instanceURL)))
                            .multilineTextAlignment(.leading)
                    }
                    .font(.body)
                    .foregroundStyle(Color.groupedMuted)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("welcome_instance_settings"))
                if let message = state.message {
                    Label {
                        Text(message.message)
                    } icon: {
                        Image(systemName: "exclamationmark.circle")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Button("account_log_out", action: onLogOut)
                    .buttonStyle(OutlinedButtonStyle())
                    .padding(.top, 16)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.groupedCard)
        .onChange(of: state.message) {
            if let message = state.message {
                AccessibilityNotification.Announcement(String(localized: message.message)).post()
            }
        }
        .alert(
            "log_out_title",
            isPresented: Binding(get: { state.isConfirmingLogout }, set: {
                if !$0 {
                    onCancelLogOut()
                }
            })
        ) {
            Button("account_log_out", role: .destructive, action: onConfirmLogOut)
            Button("instance_sheet_cancel", role: .cancel, action: onCancelLogOut)
        } message: {
            Text("log_out_message")
        }
        .alert(
            "instance_switch_title",
            isPresented: Binding(get: { state.confirmSwitchTo != nil }, set: {
                if !$0 {
                    onCancelSwitch()
                }
            })
        ) {
            Button("instance_switch_confirm", role: .destructive) {
                if let url = state.confirmSwitchTo {
                    onConfirmSwitch(url)
                }
            }
            Button("instance_sheet_cancel", role: .cancel, action: onCancelSwitch)
        } message: {
            Text(String(format: String(localized: "instance_switch_message"), instanceHost(state.instanceURL)))
        }
        .sheet(isPresented: Binding(
            get: { state.sheet != nil },
            set: {
                if !$0, state.sheet != nil {
                    onDismissInstanceSheet()
                }
            }
        )) {
            if let sheet = state.sheet {
                InstanceSheetView(
                    state: sheet,
                    onDraftChange: onDraftChange,
                    onReset: onResetDraft,
                    onDismiss: onDismissInstanceSheet,
                    onSave: onSaveInstance
                )
            }
        }
    }
}

@MainActor
private func accountPreview(_ state: AccountUiState) -> some View {
    AccountSheetView(
        state: state, onClose: {},
        onLogOut: {}, onConfirmLogOut: {}, onCancelLogOut: {}, onOpenInstanceSheet: {},
        onDraftChange: { _ in }, onResetDraft: {}, onDismissInstanceSheet: {}, onSaveInstance: {},
        onConfirmSwitch: { _ in }, onCancelSwitch: {}
    )
}

#Preview("Light") {
    accountPreview(AccountUiState(name: "Michael Scott", instanceURL: defaultInstanceURL))
}

#Preview("Offline, dark") {
    accountPreview(AccountUiState(name: "Michael Scott", instanceURL: defaultInstanceURL, message: .unreachable))
        .preferredColorScheme(.dark)
}
