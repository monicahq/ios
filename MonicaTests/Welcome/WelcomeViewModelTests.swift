import Foundation
@testable import Monica
import Testing

@MainActor
struct WelcomeViewModelTests {
    private let harness = Harness()

    private func viewModel() -> WelcomeViewModel {
        WelcomeViewModel(instanceRepository: harness.repository, checker: harness.checker, sessionManager: harness.sessionManager)
    }

    private func viewModelWithOpenSheet() -> WelcomeViewModel {
        let viewModel = viewModel()
        viewModel.openInstanceSheet()
        return viewModel
    }

    // MARK: Instance sheet

    @Test func `shows the saved instance with the sheet closed`() {
        #expect(viewModel().state == WelcomeUiState(instanceURL: harness.monica.base))
    }

    @Test func `opening the sheet fills the field with the current address`() {
        #expect(viewModelWithOpenSheet().state.sheet == InstanceSheetState(draft: harness.monica.base))
    }

    @Test func `typing changes the draft only`() {
        let viewModel = viewModelWithOpenSheet()

        viewModel.changeDraft("monica.example.com")

        #expect(viewModel.state.sheet?.draft == "monica.example.com")
        #expect(harness.repository.url == harness.monica.base)
    }

    @Test func `typing while the sheet is closed does nothing`() {
        let viewModel = viewModel()

        viewModel.changeDraft("monica.example.com")

        #expect(viewModel.state.sheet == nil)
    }

    @Test func `saving checks the instance, then stores it and closes the sheet`() async {
        let other = FakeMonica()
        let viewModel = viewModelWithOpenSheet()
        viewModel.changeDraft(other.host + "/")

        await viewModel.saveInstance()

        #expect(viewModel.state == WelcomeUiState(instanceURL: other.base))
        #expect(harness.repository.url == other.base)
        #expect(other.requests.map { $0.url.path() } == ["/api/v1/status", "/.well-known/oauth-authorization-server"])
    }

    @Test func `saving a refused instance keeps the sheet open with the reason`() async {
        let other = FakeMonica(settings: .init(isMonica: false))
        let viewModel = viewModelWithOpenSheet()
        viewModel.changeDraft(other.base)

        await viewModel.saveInstance()

        #expect(viewModel.state.sheet == InstanceSheetState(draft: other.base, error: .notMonica, refusals: 1))
        #expect(harness.repository.url == harness.monica.base)
    }

    @Test(arguments: [
        ("not an address", AuthError.invalidAddress),
        ("http://monica.example.com", .httpsRequired),
    ])
    func `saving an address the app cannot use says why without contacting anybody`(draft: String, error: AuthError) async {
        let viewModel = viewModelWithOpenSheet()
        viewModel.changeDraft(draft)

        await viewModel.saveInstance()

        #expect(viewModel.state.sheet?.error == error)
    }

    @Test func `saving the same refused address again counts another refusal`() async {
        let viewModel = viewModelWithOpenSheet()
        viewModel.changeDraft("not an address")
        await viewModel.saveInstance()

        await viewModel.saveInstance()

        #expect(viewModel.state.sheet?.refusals == 2)
    }

    @Test func `typing again clears the error`() async {
        let viewModel = viewModelWithOpenSheet()
        viewModel.changeDraft("not an address")
        await viewModel.saveInstance()

        viewModel.changeDraft("monica.example.com")

        #expect(viewModel.state.sheet?.error == nil)
    }

    @Test func `the field reporting the same text keeps the error`() async {
        let viewModel = viewModelWithOpenSheet()
        viewModel.changeDraft("not an address")
        await viewModel.saveInstance()

        viewModel.changeDraft("not an address")

        #expect(viewModel.state.sheet?.error == .invalidAddress)
    }

    @Test func `saving while the sheet is closed does nothing`() async {
        let viewModel = viewModel()

        await viewModel.saveInstance()

        #expect(viewModel.state == WelcomeUiState(instanceURL: harness.monica.base))
    }

    @Test func `reset puts the default address in the field without saving`() {
        let viewModel = viewModelWithOpenSheet()

        viewModel.resetDraft()

        #expect(viewModel.state.sheet?.draft == defaultInstanceURL)
        #expect(harness.repository.url == harness.monica.base)
    }

    @Test func `dismissing closes the sheet without saving`() {
        let viewModel = viewModelWithOpenSheet()
        viewModel.changeDraft("https://monica.example.com")

        viewModel.dismissInstanceSheet()

        #expect(viewModel.state == WelcomeUiState(instanceURL: harness.monica.base))
    }

    @Test func `changing instance forgets a sign-in in progress`() async throws {
        let other = FakeMonica()
        _ = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: false)
        let viewModel = viewModelWithOpenSheet()
        viewModel.changeDraft(other.base)

        await viewModel.saveInstance()

        #expect(!harness.store.contains(.pendingSignIn))
    }

    @Test func `a saved http address opens the sheet asking for https`() {
        harness.repository.setURL("http://monica.example.com")

        #expect(viewModel().state.sheet == InstanceSheetState(draft: "http://monica.example.com", error: .httpsRequired))
    }

    @Test func `picks up an instance changed elsewhere when it appears`() {
        let viewModel = viewModel()
        harness.repository.setURL("https://monica.example.com")

        viewModel.appeared()

        #expect(viewModel.state.instanceURL == "https://monica.example.com")
    }

    // MARK: Logging in

    private func browsingPage(_ viewModel: WelcomeViewModel) throws -> URL {
        guard case let .browsing(page) = viewModel.state.signIn else {
            Issue.record("Expected the browser to open, got \(viewModel.state.signIn)")
            throw AuthError.signInFailed
        }
        return page
    }

    @Test func `log in checks the instance, then opens its sign-in page`() async throws {
        let viewModel = viewModel()

        await viewModel.logIn()

        let page = try browsingPage(viewModel)
        #expect(page.absoluteString.hasPrefix("\(harness.monica.base)/oauth/authorize?"))
        #expect(page.absoluteString.contains("prompt=consent&") || page.absoluteString.hasSuffix("prompt=consent"))
    }

    @Test func `the answer of the browser signs the person in`() async throws {
        let viewModel = viewModel()
        await viewModel.logIn()

        try await viewModel.callbackReceived(Harness.callback(for: browsingPage(viewModel)))

        #expect(viewModel.state.signIn == .idle)
        #expect(harness.sessionManager.session?.name == "Michael Scott")
    }

    @Test func `closing the browser says sign-in was cancelled`() async {
        let viewModel = viewModel()
        await viewModel.logIn()

        viewModel.browserCancelled()

        #expect(viewModel.state.signIn == .failed(.cancelled))
    }

    @Test func `a browser that fails says sign-in failed`() async {
        let viewModel = viewModel()
        await viewModel.logIn()

        viewModel.browserFailed()

        #expect(viewModel.state.signIn == .failed(.signInFailed))
    }

    @Test func `denying access says so`() async throws {
        let viewModel = viewModel()
        await viewModel.logIn()

        try await viewModel.callbackReceived(Harness.callback(for: browsingPage(viewModel), query: "error=access_denied"))

        #expect(viewModel.state.signIn == .failed(.denied))
    }

    @Test func `an instance that cannot be reached is said before opening anything`() async {
        harness.monica.settings.unreachable = true
        let viewModel = viewModel()

        await viewModel.logIn()

        #expect(viewModel.state.signIn == .failed(.unreachable))
    }

    @Test func `log in again works after a failure`() async throws {
        let viewModel = viewModel()
        await viewModel.logIn()
        viewModel.browserCancelled()

        await viewModel.logIn()

        _ = try browsingPage(viewModel)
    }

    @Test func `a second tap while working does nothing`() async throws {
        let viewModel = viewModel()
        await viewModel.logIn()
        let page = try browsingPage(viewModel)

        await viewModel.logIn()

        #expect(try browsingPage(viewModel) == page)
    }

    @Test func `the instance sheet does not open while signing in`() async {
        let viewModel = viewModel()
        await viewModel.logIn()

        viewModel.openInstanceSheet()

        #expect(viewModel.state.sheet == nil)
    }

    // MARK: Signing up

    @Test func `sign up opens the registration page`() async throws {
        let viewModel = viewModel()

        await viewModel.signUp()

        #expect(try browsingPage(viewModel).absoluteString.contains("prompt=consent%20create"))
    }

    @Test func `sign up on an instance closed to new accounts says so without opening anything`() async {
        harness.monica.settings.registrationEnabled = false
        let viewModel = viewModel()

        await viewModel.signUp()

        #expect(viewModel.state.signIn == .failed(.registrationClosed))
        #expect(!harness.store.contains(.pendingSignIn))
    }

    @Test func `closing the browser after a sign up explains the confirmation email`() async {
        let viewModel = viewModel()
        await viewModel.signUp()

        viewModel.browserCancelled()

        #expect(viewModel.state.signIn == .failed(.signUpUnfinished))
        #expect(harness.store.contains(.pendingSignIn))
    }

    @Test func `the link of the confirmation email signs the person in`() async throws {
        let viewModel = viewModel()
        await viewModel.signUp()
        let page = try browsingPage(viewModel)
        viewModel.browserCancelled()

        try await viewModel.callbackReceived(Harness.callback(for: page))

        #expect(harness.sessionManager.session != nil)
    }

    // MARK: Session ended

    @Test func `says the session ended when it was ended elsewhere`() async throws {
        try await harness.signIn()
        harness.monica.settings.refusesRenewal = true
        harness.clock.advance(by: 3600)
        _ = try? await harness.sessionManager.authorizedGet("/api/v1/me")
        let viewModel = viewModel()

        viewModel.appeared()

        #expect(viewModel.state.signIn == .failed(.sessionEnded))
    }

    @Test func `says the session expired after a long time unused`() async throws {
        try await harness.signIn()
        harness.monica.settings.refusesRenewal = true
        harness.clock.advance(by: 31 * 24 * 3600)
        _ = try? await harness.sessionManager.authorizedGet("/api/v1/me")
        let viewModel = viewModel()

        viewModel.appeared()

        #expect(viewModel.state.signIn == .failed(.sessionExpired))
    }

    @Test func `says nothing after logging out, and says an end only once`() async throws {
        try await harness.signIn()
        await harness.sessionManager.logOut()
        let viewModel = viewModel()

        viewModel.appeared()

        #expect(viewModel.state.signIn == .idle)
    }
}
