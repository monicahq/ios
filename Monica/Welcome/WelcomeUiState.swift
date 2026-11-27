import Foundation

/// What the instance sheet shows while it is open.
struct InstanceSheetState: Equatable {
    /// What the address field shows.
    var draft: String
    /// True while the instance at the draft address is being checked, before it is saved.
    var isChecking = false
    /// Why the draft was refused, until it changes.
    var error: AuthError?
    /// How many times saving was refused while the sheet is open. Each refusal is announced to
    /// VoiceOver, even when the same error was already shown.
    var refusals = 0
}

/// Where logging in or signing up stands.
enum SignInProgress: Equatable {
    case idle
    /// Checking the instance before opening its page.
    case checking
    /// The browser sheet shows this page; the screen opens it and reports how it closed.
    case browsing(URL)
    /// Back from the browser: exchanging the answer for a session.
    case signingIn
    case failed(AuthError)

    var isBusy: Bool {
        switch self {
        case .checking, .browsing, .signingIn: true
        case .idle, .failed: false
        }
    }
}

/// Everything the welcome screen shows. `sheet` is nil when the instance sheet is closed.
struct WelcomeUiState: Equatable {
    var instanceURL: String
    var sheet: InstanceSheetState?
    var signIn: SignInProgress = .idle
}
