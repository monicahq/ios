import SwiftUI

/// Connects `VaultScreen` to its `VaultViewModel`.
struct VaultRoute: View {
    @State var viewModel: VaultViewModel
    let onBackToList: () -> Void

    var body: some View {
        VaultScreen(
            state: viewModel.state,
            onTryAgain: { Task { await viewModel.tryAgain() } },
            onBackToList: onBackToList
        )
        .task { await viewModel.load() }
    }
}

/// One vault: for now its name, colour and description, until the full vault screen arrives.
/// Stateless.
struct VaultScreen: View {
    let state: VaultUiState
    let onTryAgain: () -> Void
    let onBackToList: () -> Void

    private var title: String {
        if case let .loaded(vault) = state {
            vault.name
        } else {
            ""
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch state {
                case .loading:
                    ProgressView {
                        Text("vault_loading")
                            .foregroundStyle(Color.groupedMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                case let .loaded(vault):
                    VaultSquare(vault: vault, size: 64)
                    Text(vault.name)
                        .font(.title.bold())
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    if let description = vault.shownDescription {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(Color.ink)
                    }
                case .notFound:
                    message("vault_not_found", button: "vault_back_to_list", action: onBackToList)
                case let .failed(error):
                    message(error.message, button: "vaults_try_again", action: onTryAgain)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.groupedPage)
        .onChange(of: state) {
            switch state {
            case .notFound: AccessibilityNotification.Announcement(String(localized: "vault_not_found")).post()
            case let .failed(error): AccessibilityNotification.Announcement(String(localized: error.message)).post()
            case .loading, .loaded: break
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func message(_ text: LocalizedStringResource, button: LocalizedStringResource, action: @escaping () -> Void) -> some View {
        VStack(spacing: 20) {
            Text(text)
                .font(.body)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
            Button(String(localized: button), action: action)
                .buttonStyle(OutlinedButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }
}

#Preview("Vault") {
    NavigationStack {
        VaultScreen(
            state: .loaded(Vault(
                id: "1", name: "Work", description: "Dunder Mifflin, Scranton branch.",
                colour: .ochre, isDefault: false, contactCount: 0
            )),
            onTryAgain: {}, onBackToList: {}
        )
    }
}

#Preview("Not found, dark") {
    NavigationStack {
        VaultScreen(state: .notFound, onTryAgain: {}, onBackToList: {})
    }
    .preferredColorScheme(.dark)
}
