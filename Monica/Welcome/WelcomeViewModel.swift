import Observation

/// The welcome screen's state: the instance address and the sheet that changes it. Signing up and
/// logging in come in later features.
@MainActor
@Observable
final class WelcomeViewModel {
    private(set) var state: WelcomeUiState
    private let instanceRepository: InstanceRepository

    init(instanceRepository: InstanceRepository) {
        self.instanceRepository = instanceRepository
        state = WelcomeUiState(instanceURL: instanceRepository.url)
    }

    func openInstanceSheet() {
        state.sheet = InstanceSheetState(draft: state.instanceURL)
    }

    func changeDraft(_ draft: String) {
        state.sheet?.draft = draft
        state.sheet?.isError = false
    }

    /// Puts the default address in the field. Nothing is saved until `saveInstance()`.
    func resetDraft() {
        changeDraft(defaultInstanceURL)
    }

    func dismissInstanceSheet() {
        state.sheet = nil
    }

    /// Saves the draft and closes the sheet, or keeps it open with an error if it is not an
    /// address.
    func saveInstance() {
        guard let sheet = state.sheet else { return }
        guard let url = normalizeInstanceURL(sheet.draft) else {
            state.sheet?.isError = true
            state.sheet?.refusals += 1
            return
        }
        instanceRepository.setURL(url)
        state = WelcomeUiState(instanceURL: url)
    }
}
