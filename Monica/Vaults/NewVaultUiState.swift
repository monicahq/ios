import Foundation

/// What the form to create a vault shows.
struct NewVaultUiState: Equatable {
    var name = ""
    var description = ""
    var colour: VaultColour = .blue
    var makeDefault = false
    /// Whether "Make this the default vault" is offered: not for the account's first vault, which
    /// is always the default.
    let offersDefault: Bool
    var isSaving = false
    /// The instance's message for each field it refused ("name", "description", "colour").
    var fieldErrors: [String: String] = [:]
    /// A refusal the instance did not tie to a field.
    var generalError: String?
    /// The request did not get through (offline, ended...): said with the app's own message.
    var connectionError: AuthError?
    var isConfirmingDiscard = false

    init(offersDefault: Bool) {
        self.offersDefault = offersDefault
    }

    var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    /// Whether leaving loses something the person typed.
    var hasTypedSomething: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
