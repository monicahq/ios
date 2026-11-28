import Foundation

/// What the list of vaults shows: its content, and whether a reload is going on or failed.
struct VaultsUiState: Equatable {
    var content: VaultsContent = .loading
    /// A reload while a list is shown (pull to refresh, coming back to the list).
    var isRefreshing = false
    /// The last reload failed: the list shown is the one from before.
    var refreshFailed = false
    /// The list shown is the copy kept on the phone, last updated then, because the instance could
    /// not be reached. Nil while up to date.
    var staleSince: Date?

    /// Whether the account already holds a vault, so a new one can be made the default.
    var hasVaults: Bool {
        if case let .loaded(vaults) = content {
            !vaults.isEmpty
        } else {
            false
        }
    }
}

enum VaultsContent: Equatable {
    case loading
    /// Every vault of the account; empty means the empty state.
    case loaded([Vault])
    /// The first load failed: the message, and a way to try again.
    case failed(AuthError)
}
