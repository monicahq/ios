import SwiftUI

/// Connects `HomeScreen` to its `HomeViewModel`.
struct HomeRoute: View {
    @State var viewModel: HomeViewModel

    var body: some View {
        HomeScreen(
            state: viewModel.state,
            onLogOut: { viewModel.askToLogOut() },
            onConfirmLogOut: { Task { await viewModel.logOut() } },
            onCancelLogOut: { viewModel.cancelLogOut() },
            onOpenInstanceSheet: { viewModel.openInstanceSheet() },
            onDraftChange: { viewModel.changeDraft($0) },
            onResetDraft: { viewModel.resetDraft() },
            onDismissInstanceSheet: { viewModel.dismissInstanceSheet() },
            onSaveInstance: { Task { await viewModel.saveInstance() } },
            onConfirmSwitch: { url in Task { await viewModel.switchInstance(to: url) } },
            onCancelSwitch: { viewModel.cancelSwitch() }
        )
        .task { await viewModel.refresh() }
    }
}

/// The signed-in home, a placeholder until the signed-in app (vaults, contacts) arrives: who is
/// signed in, on which instance, and the ways out. Stateless.
struct HomeScreen: View {
    let state: HomeUiState
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

    @AccessibilityFocusState private var isGreetingFocused: Bool

    private var greeting: String {
        state.name.isEmpty ? String(localized: "home_greeting_no_name") : String(format: String(localized: "home_greeting"), state.name)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(greeting)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isGreetingFocused)
                Button(action: onOpenInstanceSheet) {
                    HStack(spacing: 8) {
                        Image(systemName: "server.rack")
                            .accessibilityHidden(true)
                        Text(String(format: String(localized: "home_connected"), instanceHost(state.instanceURL)))
                            .multilineTextAlignment(.leading)
                    }
                    .font(.body)
                    .foregroundStyle(Color.muted)
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
                Button("home_log_out", action: onLogOut)
                    .buttonStyle(OutlinedButtonStyle())
                    .padding(.top, 16)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.page)
        // Shown in place of the welcome screen once signed in: VoiceOver starts on the greeting,
        // once the browser sheet has handed focus back.
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            isGreetingFocused = true
        }
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
            Button("home_log_out", role: .destructive, action: onConfirmLogOut)
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
private func homePreview(_ state: HomeUiState) -> some View {
    HomeScreen(
        state: state,
        onLogOut: {}, onConfirmLogOut: {}, onCancelLogOut: {}, onOpenInstanceSheet: {},
        onDraftChange: { _ in }, onResetDraft: {}, onDismissInstanceSheet: {}, onSaveInstance: {},
        onConfirmSwitch: { _ in }, onCancelSwitch: {}
    )
}

#Preview("Light") {
    homePreview(HomeUiState(name: "Michael Scott", instanceURL: defaultInstanceURL))
}

#Preview("Offline, dark") {
    homePreview(HomeUiState(name: "Michael Scott", instanceURL: defaultInstanceURL, message: .unreachable))
        .preferredColorScheme(.dark)
}
