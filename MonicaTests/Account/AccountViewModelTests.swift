import Foundation
@testable import Monica
import Testing

@MainActor
struct HomeViewModelTests {
    private let harness = Harness()

    private func signedInViewModel() async throws -> HomeViewModel {
        try await harness.signIn()
        return HomeViewModel(sessionManager: harness.sessionManager, instanceRepository: harness.repository, checker: harness.checker)
    }

    @Test func `shows who is signed in, and where`() async throws {
        let viewModel = try await signedInViewModel()

        #expect(viewModel.state == HomeUiState(name: "Michael Scott", instanceURL: harness.monica.base))
    }

    @Test func `refreshing shows the name the web has now`() async throws {
        let viewModel = try await signedInViewModel()
        harness.monica.settings.meAfterSignIn = .json(200, """
        {"data":{"attributes":{"first_name":"Pam","last_name":"Beesly","email":"pam@example.com"}}}
        """)

        await viewModel.refresh()

        #expect(viewModel.state.name == "Pam Beesly")
    }

    @Test func `refreshing offline says so and stays signed in`() async throws {
        let viewModel = try await signedInViewModel()
        harness.monica.settings.unreachable = true

        await viewModel.refresh()

        #expect(viewModel.state.message == .unreachable)
        #expect(harness.sessionManager.session != nil)
    }

    @Test func `refreshing when not allowed says so`() async throws {
        let viewModel = try await signedInViewModel()
        harness.monica.settings.meAfterSignIn = .json(403, #"{"message":"Forbidden."}"#)

        await viewModel.refresh()

        #expect(viewModel.state.message == .notAllowed)
    }

    @Test func `an ended session says nothing here: the welcome screen explains it`() async throws {
        let viewModel = try await signedInViewModel()
        harness.monica.settings.refusesRenewal = true
        harness.clock.advance(by: 3600)

        await viewModel.refresh()

        #expect(viewModel.state.message == nil)
        #expect(harness.sessionManager.state == .signedOut(.ended))
    }

    @Test func `a successful refresh clears the message`() async throws {
        let viewModel = try await signedInViewModel()
        harness.monica.settings.unreachable = true
        await viewModel.refresh()
        harness.monica.settings.unreachable = false

        await viewModel.refresh()

        #expect(viewModel.state.message == nil)
    }

    // MARK: Logging out

    @Test func `log out asks first`() async throws {
        let viewModel = try await signedInViewModel()

        viewModel.askToLogOut()

        #expect(viewModel.state.isConfirmingLogout)
        #expect(harness.sessionManager.session != nil)
    }

    @Test func `cancelling keeps the person signed in`() async throws {
        let viewModel = try await signedInViewModel()
        viewModel.askToLogOut()

        viewModel.cancelLogOut()

        #expect(!viewModel.state.isConfirmingLogout)
        #expect(harness.sessionManager.session != nil)
    }

    @Test func `confirming logs out`() async throws {
        let viewModel = try await signedInViewModel()
        viewModel.askToLogOut()

        await viewModel.logOut()

        #expect(harness.sessionManager.state == .signedOut(.loggedOut))
    }

    // MARK: Switching instance

    @Test func `another instance is checked, then switching is confirmed`() async throws {
        let viewModel = try await signedInViewModel()
        let other = FakeMonica()
        viewModel.openInstanceSheet()
        viewModel.changeDraft(other.base)

        await viewModel.saveInstance()

        #expect(viewModel.state.sheet == nil)
        #expect(viewModel.state.confirmSwitchTo == other.base)
        #expect(harness.sessionManager.session != nil)
        #expect(harness.repository.url == harness.monica.base)
    }

    @Test func `confirming the switch signs out and makes the new instance current`() async throws {
        let viewModel = try await signedInViewModel()
        let other = FakeMonica()
        viewModel.openInstanceSheet()
        viewModel.changeDraft(other.base)
        await viewModel.saveInstance()

        await viewModel.switchInstance(to: other.base)

        #expect(viewModel.state.confirmSwitchTo == nil)
        #expect(harness.sessionManager.state == .signedOut(.instanceChanged))
        #expect(harness.repository.url == other.base)
        #expect(other.requests.allSatisfy { $0.headers["Authorization"] == nil })
    }

    @Test func `cancelling the switch keeps everything`() async throws {
        let viewModel = try await signedInViewModel()
        let other = FakeMonica()
        viewModel.openInstanceSheet()
        viewModel.changeDraft(other.base)
        await viewModel.saveInstance()

        viewModel.cancelSwitch()

        #expect(viewModel.state.confirmSwitchTo == nil)
        #expect(harness.sessionManager.session != nil)
        #expect(harness.repository.url == harness.monica.base)
    }

    @Test func `a refused instance leaves the session untouched`() async throws {
        let viewModel = try await signedInViewModel()
        viewModel.openInstanceSheet()
        viewModel.changeDraft("not an address")

        await viewModel.saveInstance()

        #expect(viewModel.state.sheet?.error == .invalidAddress)
        #expect(viewModel.state.sheet?.refusals == 1)
        #expect(viewModel.state.confirmSwitchTo == nil)
        #expect(harness.sessionManager.session != nil)
    }

    @Test func `the field reporting the same text keeps the error`() async throws {
        let viewModel = try await signedInViewModel()
        viewModel.openInstanceSheet()
        viewModel.changeDraft("not an address")
        await viewModel.saveInstance()

        viewModel.changeDraft("not an address")

        #expect(viewModel.state.sheet?.error == .invalidAddress)
    }

    @Test func `saving the same instance just closes the sheet`() async throws {
        let viewModel = try await signedInViewModel()
        viewModel.openInstanceSheet()

        await viewModel.saveInstance()

        #expect(viewModel.state.sheet == nil)
        #expect(viewModel.state.confirmSwitchTo == nil)
    }

    @Test func `the sheet resets, edits and closes like on the welcome screen`() async throws {
        let viewModel = try await signedInViewModel()
        viewModel.openInstanceSheet()
        viewModel.changeDraft("x")

        viewModel.resetDraft()
        #expect(viewModel.state.sheet?.draft == defaultInstanceURL)

        viewModel.dismissInstanceSheet()
        #expect(viewModel.state.sheet == nil)
    }
}
