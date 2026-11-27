/// What the screen of one vault shows.
enum VaultUiState: Equatable {
    case loading
    case loaded(Vault)
    /// The vault was deleted (on the web, by somebody else) since the list was shown.
    case notFound
    case failed(AuthError)
}
