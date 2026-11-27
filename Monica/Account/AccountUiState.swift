/// Everything the account sheet shows: who is signed in, where, and the ways out.
struct AccountUiState: Equatable {
    var name: String
    var instanceURL: String
    var isConfirmingLogout = false
    var sheet: InstanceSheetState?
    /// The checked address the person asked to switch to, while they confirm it signs them out.
    var confirmSwitchTo: String?
    /// Something to tell the person while they stay signed in (offline, not allowed...).
    var message: AuthError?

    /// The letters on the account button; nil when the name has none, so a symbol is shown.
    var initials: String? {
        personInitials(name)
    }
}
