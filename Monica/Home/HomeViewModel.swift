import Observation

/// The placeholder home of a signed-in person: who they are, where, logging out and switching
/// instance.
@MainActor
@Observable
final class HomeViewModel {
    private(set) var state: HomeUiState
    private let sessionManager: SessionManager
    private let instanceRepository: InstanceRepository
    private let checker: InstanceChecker

    init(sessionManager: SessionManager, instanceRepository: InstanceRepository, checker: InstanceChecker) {
        self.sessionManager = sessionManager
        self.instanceRepository = instanceRepository
        self.checker = checker
        state = HomeUiState(
            name: sessionManager.session?.name ?? "",
            instanceURL: sessionManager.session?.instance ?? instanceRepository.url
        )
    }

    /// Reloads who the person is. Renews access on the way when it expired; an ended session takes
    /// the person back to the welcome screen (the session manager signs out), anything else is
    /// said here while they stay signed in.
    func refresh() async {
        do {
            try await sessionManager.refreshPerson()
            state.name = sessionManager.session?.name ?? state.name
            state.message = nil
        } catch {
            switch error {
            case .sessionEnded, .sessionExpired, .cancelled: break
            default: state.message = error
            }
        }
    }

    // MARK: Logging out

    func askToLogOut() {
        state.isConfirmingLogout = true
    }

    func cancelLogOut() {
        state.isConfirmingLogout = false
    }

    func logOut() async {
        state.isConfirmingLogout = false
        await sessionManager.logOut()
    }

    // MARK: Switching instance

    func openInstanceSheet() {
        state.sheet = InstanceSheetState(draft: state.instanceURL)
    }

    /// A new draft clears the error. The field also reports its text when it stops being edited
    /// (disabled while checking): the same text is not a change, and keeps the error.
    func changeDraft(_ draft: String) {
        guard draft != state.sheet?.draft else { return }
        state.sheet?.draft = draft
        state.sheet?.error = nil
    }

    func resetDraft() {
        changeDraft(defaultInstanceURL)
    }

    func dismissInstanceSheet() {
        state.sheet = nil
    }

    /// Checks the new instance first: the person is only asked to confirm switching (which signs
    /// them out) when the app can work with it. The current session is untouched until then.
    func saveInstance() async {
        guard let sheet = state.sheet, !sheet.isChecking else { return }
        state.sheet?.isChecking = true
        state.sheet?.error = nil
        do {
            let description = try await checker.check(draft: sheet.draft)
            guard state.sheet != nil else { return }
            state.sheet = nil
            if description.base != state.instanceURL {
                state.confirmSwitchTo = description.base
            }
        } catch {
            guard state.sheet != nil else { return }
            state.sheet?.isChecking = false
            state.sheet?.error = error
            state.sheet?.refusals += 1
        }
    }

    func cancelSwitch() {
        state.confirmSwitchTo = nil
    }

    /// Signs out of the current instance, then makes `url` (the confirmed one) current: the
    /// welcome screen asks to log in to it. The address is passed in rather than read from the
    /// state, since closing the alert clears it before this runs.
    func switchInstance(to url: String) async {
        state.confirmSwitchTo = nil
        instanceRepository.setURL(url)
        await sessionManager.logOut(reason: .instanceChanged)
    }
}
