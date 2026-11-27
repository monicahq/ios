import SwiftUI

/// The app's root: the welcome screen while signed out, the list of vaults once signed in. Also where iOS
/// hands the app its return address (the link of a confirmation email opened in Safari), and
/// where a logout the instance missed is retried.
struct RootView: View {
    let sessionManager: SessionManager
    let welcome: WelcomeViewModel
    let vaultRepository: VaultRepository
    let makeAccount: () -> AccountViewModel

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch sessionManager.state {
            case .signedIn:
                VaultsRoute(
                    viewModel: VaultsViewModel(repository: vaultRepository),
                    account: makeAccount(),
                    makeVault: { [vaultRepository] in VaultViewModel(id: $0, repository: vaultRepository) },
                    makeNewVault: { [vaultRepository] in NewVaultViewModel(offersDefault: $0, repository: vaultRepository) }
                )
            case .signedOut:
                WelcomeRoute(viewModel: welcome)
            }
        }
        .onOpenURL { url in
            Task { await welcome.callbackReceived(url) }
        }
        .task { await sessionManager.retryPendingRevocation() }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task { await sessionManager.retryPendingRevocation() }
            }
        }
    }
}
