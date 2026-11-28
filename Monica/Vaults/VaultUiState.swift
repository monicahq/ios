import Foundation

/// What the screen of one vault shows.
enum VaultUiState: Equatable {
    case loading
    /// The vault, and since when it is not up to date when it is the copy kept on the phone shown
    /// because the instance could not be reached.
    case loaded(Vault, staleSince: Date?)
    /// The vault was deleted (on the web, by somebody else) since the list was shown.
    case notFound
    case failed(AuthError)
}

extension VaultUiState {
    /// Since when the vault shown is not up to date; nil while up to date or when none is shown.
    var staleSince: Date? {
        if case let .loaded(_, staleSince) = self {
            staleSince
        } else {
            nil
        }
    }
}
