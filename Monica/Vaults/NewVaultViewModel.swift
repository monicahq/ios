import Foundation
import Observation

/// The form to create a vault: a name, a description, one of the eight colours, and whether it
/// becomes the default. The instance decides what it accepts (the plan's ceiling, the name's
/// length) and the form shows what it says.
@MainActor
@Observable
final class NewVaultViewModel {
    private(set) var state: NewVaultUiState
    private let repository: VaultRepository

    init(offersDefault: Bool, repository: VaultRepository) {
        state = NewVaultUiState(offersDefault: offersDefault)
        self.repository = repository
    }

    func changeName(_ name: String) {
        guard name != state.name else { return }
        state.name = name
        state.fieldErrors["name"] = nil
        state.connectionError = nil
    }

    func changeDescription(_ description: String) {
        guard description != state.description else { return }
        state.description = description
        state.fieldErrors["description"] = nil
        state.connectionError = nil
    }

    func chooseColour(_ colour: VaultColour) {
        state.colour = colour
        state.fieldErrors["colour"] = nil
    }

    func toggleMakeDefault() {
        state.makeDefault.toggle()
    }

    /// Creates the vault and returns it, or nil when it was not created: the form then says why and
    /// keeps everything typed.
    func create() async -> Vault? {
        guard state.canCreate else { return nil }
        state.isSaving = true
        state.fieldErrors = [:]
        state.generalError = nil
        state.connectionError = nil
        defer { state.isSaving = false }
        do {
            return try await repository.create(NewVault(
                name: state.name,
                description: state.description,
                colour: state.colour,
                makeDefault: state.offersDefault && state.makeDefault
            ))
        } catch {
            show(error)
            return nil
        }
    }

    private func show(_ error: ApiError) {
        switch error {
        case let .invalid(refusal):
            let known = refusal.fields.filter { ["name", "description", "colour"].contains($0.key) }
            state.fieldErrors = known
            if known.isEmpty {
                state.generalError = refusal.message
            }
        case .failed(.sessionEnded), .failed(.sessionExpired), .failed(.cancelled):
            break
        case let .failed(error):
            state.connectionError = error
        case .notFound:
            state.connectionError = .unexpectedAnswer
        }
    }

    // MARK: Leaving

    /// Closes the form at once when nothing was typed, and returns true; otherwise asks first.
    func cancel() -> Bool {
        if state.hasTypedSomething {
            state.isConfirmingDiscard = true
            return false
        }
        return true
    }

    func keepEditing() {
        state.isConfirmingDiscard = false
    }
}
