import Observation

/// The screen of one vault, for now its name, colour and description: the full vault screen is a
/// later feature.
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
        state = .loading
        do {
            state = try await .loaded(repository.vault(id: id))
        } catch {
            switch error {
            case .notFound: state = .notFound
            case .failed(.sessionEnded), .failed(.sessionExpired), .failed(.cancelled): break
            case let .failed(error): state = .failed(error)
            case .invalid: state = .failed(.unexpectedAnswer)
            }
        }
    }

    func tryAgain() async {
        await load()
    }
}
