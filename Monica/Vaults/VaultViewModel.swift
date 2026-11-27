import Foundation
import Observation

/// The screen of one vault, for now its name, colour and description: the full vault screen is a
/// later feature. Shows the copy kept on the phone at once when there is one, then the instance's
/// answer; offline, the copy stays, said not up to date.
@MainActor
@Observable
final class VaultViewModel {
    private(set) var state: VaultUiState = .loading
    let id: String
    private let repository: VaultRepository

    init(id: String, repository: VaultRepository) {
        self.id = id
        self.repository = repository
    }

    func load() async {
        let cached = repository.cachedVault(id: id)
        // A "not up to date" line already shown stays until the instance answers.
        let shownStale = state.staleSince
        state = cached.map { .loaded($0.value, staleSince: shownStale) } ?? .loading
        do {
            state = try await .loaded(repository.vault(id: id), staleSince: nil)
        } catch {
            switch error {
            case .notFound: state = .notFound
            case .failed(.sessionEnded), .failed(.sessionExpired), .failed(.cancelled): break
            case let .failed(error):
                if let cached {
                    state = .loaded(cached.value, staleSince: cached.updatedAt)
                } else {
                    state = .failed(error)
                }
            case .invalid: state = .failed(.unexpectedAnswer)
            }
        }
    }

    func tryAgain() async {
        await load()
    }
}
