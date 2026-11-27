/// What the instance sheet shows while it is open.
struct InstanceSheetState: Equatable {
    /// What the address field shows.
    var draft: String
    /// True after saving an address the app cannot use, until the draft changes.
    var isError = false
    /// How many times saving was refused while the sheet is open. Each refusal is announced to
    /// VoiceOver, even when the error was already shown.
    var refusals = 0
}

/// Everything the welcome screen shows. `sheet` is nil when the instance sheet is closed.
struct WelcomeUiState: Equatable {
    var instanceURL: String
    var sheet: InstanceSheetState?
}
