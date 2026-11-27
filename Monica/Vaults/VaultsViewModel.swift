import Observation

/// The list of vaults a signed-in person lands on. Loads it from the instance each time the list
/// appears, so a vault created, renamed or deleted elsewhere shows without asking.
@MainActor
@Observable
final class VaultsViewModel {
    private(set) var state = VaultsUiState()
    private let repository: VaultRepository

    init(repository: VaultRepository) {
        self.repository = repository
    }

    /// Loads the list. The first time, the screen shows that it is loading; afterwards the list
    /// stays shown and is only replaced once the new one arrived. An ended session says nothing
    /// here: the app goes back to the welcome screen, which explains.
    func load() async {
        let hasContent = if case .loaded = state.content {
            true
        } else {
            false
        }
        if hasContent {
            state.isRefreshing = true
        } else {
            state.content = .loading
        }
        defer { state.isRefreshing = false }
        do {
            state.content = try await .loaded(repository.vaults())
            state.refreshFailed = false
        } catch {
            guard let shown = Self.message(for: error) else { return }
            if hasContent {
                state.refreshFailed = true
            } else {
                state.content = .failed(shown)
            }
        }
    }

    func tryAgain() async {
        await load()
    }

    func dismissRefreshMessage() {
        state.refreshFailed = false
    }

    /// What to tell the person, or nil when nothing should be said here.
    private static func message(for error: ApiError) -> AuthError? {
        switch error {
        case .failed(.sessionEnded), .failed(.sessionExpired), .failed(.cancelled): nil
        case let .failed(error): error
        case .notFound, .invalid: .unexpectedAnswer
        }
    }
}
