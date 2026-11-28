import Foundation
import Observation

/// The list of vaults a signed-in person lands on. Shows the copy kept on the phone at once, then
/// loads the list from the instance each time it appears, so a vault created, renamed or deleted
/// elsewhere shows without asking. Offline, the copy stays, said not up to date.
@MainActor
@Observable
final class VaultsViewModel {
    private(set) var state = VaultsUiState()
    private let repository: VaultRepository

    init(repository: VaultRepository) {
        self.repository = repository
    }

    /// Loads the list. With nothing shown yet, the copy kept on the phone shows at once, or else
    /// the screen shows that it is loading; afterwards the list stays shown and is only replaced
    /// once the new one arrived. When the instance cannot answer, a list shown stays, said not up
    /// to date; a reload asked while one was shown also says it failed. An ended session says
    /// nothing here: the app goes back to the welcome screen, which explains.
    func load() async {
        let wasShown = if case .loaded = state.content {
            true
        } else {
            false
        }
        var copyDate = state.staleSince
        if !wasShown, let cached = repository.cachedVaults() {
            state.content = .loaded(cached.value)
            copyDate = cached.updatedAt
        } else if wasShown {
            copyDate = copyDate ?? repository.cachedVaults()?.updatedAt
        }
        if case .loaded = state.content {
            state.isRefreshing = true
        } else {
            state.content = .loading
        }
        defer { state.isRefreshing = false }
        do {
            state.content = try await .loaded(repository.vaults())
            state.refreshFailed = false
            state.staleSince = nil
        } catch {
            guard let shown = Self.message(for: error) else { return }
            if case .loaded = state.content {
                state.refreshFailed = wasShown
                state.staleSince = copyDate
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
