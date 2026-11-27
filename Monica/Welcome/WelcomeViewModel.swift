import Foundation
import Observation

/// The welcome screen's state: the instance, the sheet that changes it, and logging in or signing
/// up through the instance's own pages.
@MainActor
@Observable
final class WelcomeViewModel {
    private(set) var state: WelcomeUiState
    private let instanceRepository: InstanceRepository
    private let checker: InstanceChecker
    private let sessionManager: SessionManager
    /// The session generation whose end was already explained, so it is said once.
    private var explainedGeneration: Int?

    init(instanceRepository: InstanceRepository, checker: InstanceChecker, sessionManager: SessionManager) {
        self.instanceRepository = instanceRepository
        self.checker = checker
        self.sessionManager = sessionManager
        state = WelcomeUiState(instanceURL: instanceRepository.url)
        requireUsableAddress()
    }

    /// Called each time the screen appears: picks up an instance changed from the home, and says
    /// why the person was signed out when the session ended on its own.
    func appeared() {
        if state.instanceURL != instanceRepository.url {
            state = WelcomeUiState(instanceURL: instanceRepository.url)
        }
        guard explainedGeneration != sessionManager.generation,
              case let .signedOut(reason) = sessionManager.state
        else { return }
        explainedGeneration = sessionManager.generation
        switch reason {
        case .expired: state.signIn = .failed(.sessionExpired)
        case .ended: state.signIn = .failed(.sessionEnded)
        case .loggedOut, .instanceChanged, nil: break
        }
    }

    // MARK: Logging in and signing up

    func logIn() async {
        await start(isSignUp: false)
    }

    func signUp() async {
        await start(isSignUp: true)
    }

    /// Checks the instance (it may have changed since it was saved), then hands the page to open
    /// to the screen.
    private func start(isSignUp: Bool) async {
        guard !state.signIn.isBusy, state.sheet == nil else { return }
        state.signIn = .checking
        do {
            let description = try await checker.check(draft: state.instanceURL)
            if isSignUp, !description.registrationEnabled {
                state.signIn = .failed(.registrationClosed)
                return
            }
            state.signIn = try .browsing(sessionManager.startSignIn(description, isSignUp: isSignUp))
        } catch {
            state.signIn = .failed(error)
        }
    }

    /// The browser sheet closed with an answer, or iOS opened the app with one (the link of a
    /// confirmation email).
    func callbackReceived(_ url: URL) async {
        state.signIn = .signingIn
        do {
            try await sessionManager.complete(callback: url, currentInstance: state.instanceURL)
            state.signIn = .idle
        } catch {
            state.signIn = .failed(error)
        }
    }

    /// The person closed the browser sheet. After a sign up, they may be off to read the
    /// confirmation email, whose link still completes the attempt.
    func browserCancelled() {
        state.signIn = .failed(sessionManager.pendingSignInIsSignUp ? .signUpUnfinished : .cancelled)
    }

    /// The browser sheet could not open or failed on its own.
    func browserFailed() {
        state.signIn = .failed(.signInFailed)
    }

    // MARK: Instance sheet

    func openInstanceSheet() {
        guard !state.signIn.isBusy else { return }
        state.sheet = InstanceSheetState(draft: state.instanceURL)
    }

    /// A new draft clears the error. The field also reports its text when it stops being edited
    /// (disabled while checking): the same text is not a change, and keeps the error.
    func changeDraft(_ draft: String) {
        guard draft != state.sheet?.draft else { return }
        state.sheet?.draft = draft
        state.sheet?.error = nil
    }

    /// Puts the default address in the field. Nothing is saved until `saveInstance()`.
    func resetDraft() {
        changeDraft(defaultInstanceURL)
    }

    func dismissInstanceSheet() {
        state.sheet = nil
        requireUsableAddress()
    }

    /// Checks the instance at the draft address and saves it only if the app can work with it;
    /// otherwise keeps the sheet open with the reason. The saved instance is untouched meanwhile.
    func saveInstance() async {
        guard let sheet = state.sheet, !sheet.isChecking else { return }
        state.sheet?.isChecking = true
        state.sheet?.error = nil
        do {
            let description = try await checker.check(draft: sheet.draft)
            // Closed while checking: the person changed their mind.
            guard state.sheet != nil else { return }
            if description.base != state.instanceURL {
                sessionManager.forgetPendingSignIn()
            }
            instanceRepository.setURL(description.base)
            state = WelcomeUiState(instanceURL: description.base)
        } catch {
            guard state.sheet != nil else { return }
            state.sheet?.isChecking = false
            state.sheet?.error = error
            state.sheet?.refusals += 1
        }
    }

    /// An address saved by an earlier version may be plain `http`, which this build refuses: the
    /// sheet opens on it, saying why, until it is corrected.
    private func requireUsableAddress() {
        if case let .failure(error) = normalizeInstanceURL(state.instanceURL, allowsHTTP: checker.allowsHTTP) {
            state.sheet = InstanceSheetState(draft: state.instanceURL, error: error)
        }
    }
}
