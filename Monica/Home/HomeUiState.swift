/// Everything the placeholder home shows, until the signed-in app (vaults, contacts) arrives.
struct HomeUiState: Equatable {
    var name: String
    var instanceURL: String
    var isConfirmingLogout = false
    var sheet: InstanceSheetState?
    /// The checked address the person asked to switch to, while they confirm it signs them out.
    var confirmSwitchTo: String?
    /// Something to tell the person while they stay signed in (offline, not allowed...).
    var message: AuthError?
}
