import SwiftUI

/// Where the list of vaults can lead.
struct VaultDestination: Hashable {
    let id: String
}

/// The signed-in app's home: the list of vaults, the screens it opens and its sheets.
struct VaultsRoute: View {
    @State var viewModel: VaultsViewModel
    @State var account: AccountViewModel
    let makeVault: (String) -> VaultViewModel
    let makeNewVault: (_ offersDefault: Bool) -> NewVaultViewModel

    @State private var path: [VaultDestination] = []
    @State private var isShowingAccount = false
    @State private var newVault: NewVaultViewModel?

    var body: some View {
        NavigationStack(path: $path) {
            VaultsScreen(
                state: viewModel.state,
                initials: account.state.initials,
                accountName: account.state.name,
                onVaultTap: { path.append(VaultDestination(id: $0)) },
                onNewVault: { newVault = makeNewVault(viewModel.state.hasVaults) },
                onRefresh: { await viewModel.load() },
                onTryAgain: { Task { await viewModel.tryAgain() } },
                onDismissRefreshMessage: { viewModel.dismissRefreshMessage() },
                onAccount: { isShowingAccount = true }
            )
            // Each time the list appears, also when coming back from a vault: the instance is the
            // source of truth, and a vault may have changed meanwhile.
            .task { await viewModel.load() }
            .navigationDestination(for: VaultDestination.self) { destination in
                VaultRoute(viewModel: makeVault(destination.id), onBackToList: { path.removeAll() })
            }
        }
        .sheet(isPresented: Binding(get: { newVault != nil }, set: {
            if !$0 {
                newVault = nil
            }
        })) {
            if let newVault {
                NewVaultRoute(
                    viewModel: newVault,
                    onCreated: { vault in
                        self.newVault = nil
                        AccessibilityNotification.Announcement(
                            String(format: String(localized: "vaults_created"), vault.name)
                        ).post()
                        // The instance decides where it goes and which vault is the default.
                        Task { await viewModel.load() }
                    },
                    onClose: { self.newVault = nil }
                )
            }
        }
        // Who is signed in, as the web has it now: the initials and the account sheet use it.
        .task { await account.refresh() }
        .sheet(isPresented: $isShowingAccount) {
            AccountSheetView(
                state: account.state,
                onClose: { isShowingAccount = false },
                onLogOut: { account.askToLogOut() },
                onConfirmLogOut: { Task { await account.logOut() } },
                onCancelLogOut: { account.cancelLogOut() },
                onOpenInstanceSheet: { account.openInstanceSheet() },
                onDraftChange: { account.changeDraft($0) },
                onResetDraft: { account.resetDraft() },
                onDismissInstanceSheet: { account.dismissInstanceSheet() },
                onSaveInstance: { Task { await account.saveInstance() } },
                onConfirmSwitch: { url in Task { await account.switchInstance(to: url) } },
                onCancelSwitch: { account.cancelSwitch() }
            )
        }
    }
}

/// All the vaults of the account, as cards. Stateless.
struct VaultsScreen: View {
    let state: VaultsUiState
    let initials: String?
    let accountName: String
    let onVaultTap: (String) -> Void
    let onNewVault: () -> Void
    let onRefresh: () async -> Void
    let onTryAgain: () -> Void
    let onDismissRefreshMessage: () -> Void
    let onAccount: () -> Void

    @AccessibilityFocusState private var isTitleFocused: Bool
    /// The title takes VoiceOver's focus once, when the list replaces the welcome screen, not each
    /// time the person comes back from a vault.
    @State private var didFocusTitle = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    private var vaults: [Vault]? {
        if case let .loaded(vaults) = state.content, !vaults.isEmpty {
            vaults
        } else {
            nil
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("vaults_title")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isTitleFocused)
                        .accessibilityAction(named: Text("vaults_refresh")) { Task { await onRefresh() } }
                        .padding(.horizontal, 4)
                        .fixedSize(horizontal: false, vertical: true)
                    StaleNoticeView(since: state.staleSince)
                        .padding(.horizontal, 4)
                    content(minHeight: geometry.size.height * 0.6)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .refreshable { await onRefresh() }
        }
        .background(Color.groupedPage)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if vaults != nil {
                newVaultButton
            }
        }
        // Shown in place of the welcome screen once signed in: VoiceOver starts on the title, once
        // the browser sheet has handed focus back.
        .task {
            guard !didFocusTitle else { return }
            didFocusTitle = true
            try? await Task.sleep(for: .milliseconds(300))
            isTitleFocused = true
        }
        // One announcement when a reload fails offline: a second one would cut the first off.
        .onChange(of: state.refreshFailed) {
            if state.refreshFailed {
                let failed = String(localized: "vaults_refresh_failed")
                let text = state.staleSince.map { staleAnnouncement(since: $0, prefix: failed, now: .now, locale: locale) } ?? failed
                AccessibilityNotification.Announcement(text).post()
            }
        }
        .onChange(of: state.staleSince == nil) {
            guard !state.refreshFailed else { return }
            AccessibilityNotification.Announcement(staleAnnouncement(since: state.staleSince, now: .now, locale: locale)).post()
        }
        .onChange(of: state.content) {
            if case let .failed(error) = state.content {
                AccessibilityNotification.Announcement(String(localized: error.message)).post()
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button(action: onAccount) {
                Group {
                    if let initials {
                        // Capped as the system caps bar buttons: the Large Content Viewer shows it big.
                        Text(initials)
                            .font(.subheadline.weight(.semibold))
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.body)
                    }
                }
                .foregroundStyle(Color.ink)
                .frame(width: 36, height: 36)
                .background(Color.hairline, in: Circle())
                .frame(width: 44, height: 44)
                .floatingCircle()
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("account_button"))
            .accessibilityValue(Text(accountName))
            .accessibilityShowsLargeContentViewer {
                Label {
                    Text("account_button")
                } icon: {
                    Image(systemName: "person.crop.circle")
                }
            }
            Spacer()
            Image(.logo)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 25)
                .accessibilityHidden(true)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background {
            // Cards fade under the floating controls, as in the design.
            LinearGradient(
                stops: [.init(color: Color.groupedPage, location: 0.55), .init(color: Color.groupedPage.opacity(0), location: 1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    private var newVaultButton: some View {
        Button(action: onNewVault) {
            Label("vaults_new", systemImage: "plus")
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .frame(minHeight: 52)
        }
        .floatingPrimaryButton()
        .padding(.bottom, 8)
    }

    // MARK: Content

    @ViewBuilder
    private func content(minHeight: CGFloat) -> some View {
        switch state.content {
        case .loading:
            ProgressView {
                Text("vaults_loading")
                    .foregroundStyle(Color.groupedMuted)
            }
            .frame(maxWidth: .infinity, minHeight: minHeight)
        case let .failed(error):
            VStack(spacing: 20) {
                Text(error.message)
                    .font(.body)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("vaults_try_again", action: onTryAgain)
                    .buttonStyle(OutlinedButtonStyle())
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: minHeight)
        case let .loaded(vaults) where vaults.isEmpty:
            emptyState
                .frame(maxWidth: .infinity, minHeight: minHeight)
        case let .loaded(vaults):
            if state.refreshFailed {
                refreshMessage
            }
            LazyVStack(spacing: 16) {
                ForEach(vaults) { vault in
                    VaultCardView(vault: vault, isAccessibilitySize: dynamicTypeSize.isAccessibilitySize) {
                        onVaultTap(vault.id)
                    }
                    .accessibilityAction(named: Text("vaults_refresh")) { Task { await onRefresh() } }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox")
                .font(.title)
                .foregroundStyle(Color.groupedMuted)
                .frame(width: 64, height: 64)
                .background(Color.groupedCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("vaults_empty_title")
                    .font(.title2.bold())
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("vaults_empty_body")
                    .font(.body)
                    .foregroundStyle(Color.groupedMuted)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            Button(action: onNewVault) {
                Label("vaults_new", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
    }

    private var refreshMessage: some View {
        let buttons = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .accessibilityHidden(true)
                Text("vaults_refresh_failed")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            // Trying again without the pull gesture, for whoever cannot drag.
            buttons {
                Button("vaults_try_again") { Task { await onRefresh() } }
                    .buttonStyle(TextButtonStyle())
                Button("vaults_dismiss", action: onDismissRefreshMessage)
                    .buttonStyle(TextButtonStyle())
            }
            .padding(.leading, -12)
        }
        .font(.subheadline)
        .foregroundStyle(Color.ink)
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .background(Color.groupedCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

@MainActor
private func vaultsPreview(_ state: VaultsUiState) -> some View {
    VaultsScreen(
        state: state, initials: "MS", accountName: "Michael Scott",
        onVaultTap: { _ in }, onNewVault: {}, onRefresh: {}, onTryAgain: {}, onDismissRefreshMessage: {}, onAccount: {}
    )
}

private let previewVaults = [
    Vault(id: "1", name: "Personal", description: nil, colour: .blue, isDefault: true, contactCount: 25),
    Vault(id: "2", name: "Family", description: nil, colour: .green, isDefault: false, contactCount: 1),
    Vault(id: "3", name: "Work", description: nil, colour: .ochre, isDefault: false, contactCount: 0),
]

#Preview("Vaults") {
    vaultsPreview(VaultsUiState(content: .loaded(previewVaults)))
}

#Preview("Vaults, dark, could not refresh") {
    vaultsPreview(VaultsUiState(content: .loaded(previewVaults), refreshFailed: true))
        .preferredColorScheme(.dark)
}

#Preview("Vaults, offline") {
    vaultsPreview(VaultsUiState(content: .loaded(previewVaults), staleSince: .now.addingTimeInterval(-3 * 3600)))
}

#Preview("Vaults, dark, offline, could not refresh") {
    vaultsPreview(VaultsUiState(content: .loaded(previewVaults), refreshFailed: true, staleSince: .now.addingTimeInterval(-3 * 3600)))
        .preferredColorScheme(.dark)
}

#Preview("Empty") {
    vaultsPreview(VaultsUiState(content: .loaded([])))
}

#Preview("Failed") {
    vaultsPreview(VaultsUiState(content: .failed(.unreachable)))
}
