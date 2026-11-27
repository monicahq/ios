import Foundation
@testable import Monica
import Testing

@MainActor
struct NewVaultViewModelTests {
    private let harness = Harness()

    private func signedIn(
        offersDefault: Bool = true,
        vaults: [FakeMonica.Vault] = FakeMonica.threeVaults
    ) async throws -> NewVaultViewModel {
        harness.monica.settings.vaults = vaults
        try await harness.signIn()
        return NewVaultViewModel(offersDefault: offersDefault, repository: harness.vaultRepository)
    }

    private var lastPost: [String: AnyHashable]? {
        harness.monica.requests.last { $0.method == "POST" && $0.url.path().hasSuffix("/api/v1/vaults") }
            .flatMap { try? JSONSerialization.jsonObject(with: $0.body) as? [String: AnyHashable] }
    }

    @Test func `starts empty, in the first colour`() async throws {
        let viewModel = try await signedIn()

        #expect(viewModel.state == NewVaultUiState(offersDefault: true))
        #expect(viewModel.state.colour == .blue)
        #expect(!viewModel.state.canCreate)
        #expect(!viewModel.state.hasTypedSomething)
    }

    @Test(arguments: ["", "   ", "\n"])
    func `a blank name cannot be created`(name: String) async throws {
        let viewModel = try await signedIn()
        viewModel.changeName(name)

        #expect(!viewModel.state.canCreate)
        #expect(await viewModel.create() == nil)
        #expect(lastPost == nil)
    }

    @Test func `creates the vault with what was typed`() async throws {
        let viewModel = try await signedIn()
        viewModel.changeName("  Book club ")
        viewModel.changeDescription("Readers")
        viewModel.chooseColour(.teal)
        viewModel.toggleMakeDefault()

        let vault = try #require(await viewModel.create())

        #expect(vault.name == "Book club")
        #expect(vault.isDefault)
        #expect(lastPost == ["name": "Book club", "description": "Readers", "colour": "#2f7f86", "is_default": true])
        #expect(!viewModel.state.isSaving)
    }

    @Test func `a blank description is not sent, nor default unless asked`() async throws {
        let viewModel = try await signedIn()
        viewModel.changeName("Book club")
        viewModel.changeDescription("  ")

        _ = await viewModel.create()

        #expect(lastPost == ["name": "Book club", "colour": "#3f5fd0"])
    }

    @Test func `the first vault never asks to be the default, and is`() async throws {
        let viewModel = try await signedIn(offersDefault: false, vaults: [])
        viewModel.changeName("Personal")
        viewModel.toggleMakeDefault()

        let vault = try #require(await viewModel.create())

        #expect(vault.isDefault)
        #expect(lastPost?["is_default"] == nil)
    }

    @Test func `the plan's ceiling is said under the name, and everything typed stays`() async throws {
        let viewModel = try await signedIn()
        harness.monica.settings.vaultLimit = 3
        viewModel.changeName("Work 2")
        viewModel.changeDescription("Second job")
        viewModel.chooseColour(.rose)

        #expect(await viewModel.create() == nil)

        #expect(viewModel.state.fieldErrors["name"]?.hasPrefix("The free plan holds 3 vault") == true)
        #expect(viewModel.state.name == "Work 2")
        #expect(viewModel.state.description == "Second job")
        #expect(viewModel.state.colour == .rose)
        #expect(viewModel.state.generalError == nil)
    }

    @Test func `each refused field shows its message, and a refusal without field shows above the button`() async throws {
        let viewModel = try await signedIn()
        viewModel.changeName("Book club")
        harness.monica.settings.override = { request in
            guard request.method == "POST" else { return nil }
            return .json(422, #"{"message":"Bad.","errors":{"description":["Too long."],"colour":["Unknown."],"other":["?"]}}"#)
        }

        _ = await viewModel.create()

        #expect(viewModel.state.fieldErrors == ["description": "Too long.", "colour": "Unknown."])
        #expect(viewModel.state.generalError == nil)

        harness.monica.settings.override = { request in
            request.method == "POST" ? .json(422, #"{"message":"Not now."}"#) : nil
        }
        _ = await viewModel.create()

        #expect(viewModel.state.fieldErrors.isEmpty)
        #expect(viewModel.state.generalError == "Not now.")
    }

    @Test func `changing a field clears its error`() async throws {
        let viewModel = try await signedIn()
        harness.monica.settings.vaultLimit = 3
        viewModel.changeName("Work 2")
        _ = await viewModel.create()

        viewModel.changeName("Work two")

        #expect(viewModel.state.fieldErrors["name"] == nil)
    }

    @Test func `a connection failure says so and keeps the values`() async throws {
        let viewModel = try await signedIn()
        viewModel.changeName("Book club")
        harness.monica.settings.unreachable = true

        #expect(await viewModel.create() == nil)

        #expect(viewModel.state.connectionError == .unreachable)
        #expect(viewModel.state.name == "Book club")
        #expect(viewModel.state.canCreate)
    }

    @Test func `tapping twice creates one vault`() async throws {
        let viewModel = try await signedIn()
        viewModel.changeName("Book club")
        harness.monica.settings.override = { request in
            request.method == "POST" ? .delayed(0.3, .json(201, """
            {"data":{"id":"x","attributes":{"name":"Book club","description":null,"colour":"#3f5fd0","is_default":false,"contact_count":0}}}
            """)) : nil
        }

        async let first = viewModel.create()
        async let second = viewModel.create()
        let results = await [first, second]

        #expect(results.compactMap(\.self).count == 1)
        #expect(harness.monica.requests.filter { $0.method == "POST" && $0.url.path().hasSuffix("/api/v1/vaults") }.count == 1)
    }

    @Test func `an ended session says nothing here`() async throws {
        let viewModel = try await signedIn()
        viewModel.changeName("Book club")
        harness.monica.settings.refusesRenewal = true
        harness.clock.advance(by: 3600)

        #expect(await viewModel.create() == nil)

        #expect(viewModel.state.connectionError == nil)
        #expect(harness.sessionManager.state == .signedOut(.ended))
    }

    // MARK: Leaving

    @Test func `cancelling an untouched form closes it`() async throws {
        let viewModel = try await signedIn()

        #expect(viewModel.cancel())
        #expect(!viewModel.state.isConfirmingDiscard)
    }

    @Test func `cancelling with something typed asks first, and keep editing keeps it`() async throws {
        let viewModel = try await signedIn()
        viewModel.changeDescription("Readers")

        #expect(!viewModel.cancel())
        #expect(viewModel.state.isConfirmingDiscard)

        viewModel.keepEditing()

        #expect(!viewModel.state.isConfirmingDiscard)
        #expect(viewModel.state.description == "Readers")
    }
}
