import Foundation
@testable import Monica
import Testing

@MainActor
struct VaultViewModelTests {
    private let harness = Harness()

    private func signedIn(id: String) async throws -> VaultViewModel {
        harness.monica.settings.vaults = FakeMonica.threeVaults
        try await harness.signIn()
        return VaultViewModel(id: id, repository: harness.vaultRepository)
    }

    @Test func `starts loading`() async throws {
        #expect(try await signedIn(id: "work").state == .loading)
    }

    @Test func `shows the vault`() async throws {
        let viewModel = try await signedIn(id: "work")

        await viewModel.load()

        guard case let .loaded(vault) = viewModel.state else {
            Issue.record("Expected the vault, got \(viewModel.state)")
            return
        }
        #expect(vault.name == "Work")
        #expect(vault.shownDescription == "Dunder Mifflin, Scranton branch.")
        #expect(vault.colour == .ochre)
    }

    @Test func `a vault deleted meanwhile is not found`() async throws {
        let viewModel = try await signedIn(id: "work")
        harness.monica.settings.goneVaultIDs = ["work"]

        await viewModel.load()

        #expect(viewModel.state == .notFound)
    }

    @Test func `a failure says why, and trying again loads the vault`() async throws {
        let viewModel = try await signedIn(id: "family")
        harness.monica.settings.unreachable = true
        await viewModel.load()
        #expect(viewModel.state == .failed(.unreachable))
        harness.monica.settings.unreachable = false

        await viewModel.tryAgain()

        #expect(viewModel.state.vaultName == "Family")
    }

    @Test func `an ended session says nothing here`() async throws {
        let viewModel = try await signedIn(id: "family")
        harness.monica.settings.refusesRenewal = true
        harness.clock.advance(by: 3600)

        await viewModel.load()

        #expect(viewModel.state == .loading)
    }

    @Test func `a refusal is an unexpected answer`() async throws {
        let viewModel = try await signedIn(id: "family")
        harness.monica.settings.override = { request in
            request.url.path().hasSuffix("/vaults/family") ? .json(422, #"{"message":"No."}"#) : nil
        }

        await viewModel.load()

        #expect(viewModel.state == .failed(.unexpectedAnswer))
    }
}

private extension VaultUiState {
    var vaultName: String? {
        if case let .loaded(vault) = self {
            vault.name
        } else {
            nil
        }
    }
}
