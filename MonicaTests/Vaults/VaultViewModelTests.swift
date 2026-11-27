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

        guard case let .loaded(vault, nil) = viewModel.state else {
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

    // MARK: The offline copy

    /// The list loaded, then the instance out of reach an hour later.
    private func offlineAfterLoadingTheList(id: String) async throws -> (viewModel: VaultViewModel, loadedAt: Date) {
        harness.monica.settings.vaults = FakeMonica.threeVaults
        try await harness.signIn()
        _ = try await harness.vaultRepository.vaults()
        let loadedAt = harness.clock.now
        harness.clock.advance(by: 3600)
        harness.monica.settings.unreachable = true
        return (VaultViewModel(id: id, repository: harness.vaultRepository), loadedAt)
    }

    @Test func `offline, a vault of the list opens from the copy, said not up to date`() async throws {
        let (viewModel, loadedAt) = try await offlineAfterLoadingTheList(id: "work")

        await viewModel.load()

        #expect(viewModel.state.vaultName == "Work")
        #expect(viewModel.state.staleSince == loadedAt)
    }

    @Test func `online, the copy is replaced in place by the instance's answer`() async throws {
        let (viewModel, _) = try await offlineAfterLoadingTheList(id: "work")
        await viewModel.load()
        harness.monica.settings.unreachable = false
        harness.monica.settings.vaults[2].name = "Office"

        await viewModel.load()

        #expect(viewModel.state.vaultName == "Office")
        #expect(viewModel.state.staleSince == nil)
    }

    @Test func `a vault the instance no longer has is not found, and leaves the copy`() async throws {
        let (viewModel, _) = try await offlineAfterLoadingTheList(id: "work")
        harness.monica.settings.unreachable = false
        harness.monica.settings.goneVaultIDs = ["work"]

        await viewModel.load()

        #expect(viewModel.state == .notFound)
        #expect(harness.vaultRepository.cachedVault(id: "work") == nil)
    }

    @Test func `reloading offline keeps saying not up to date while it asks`() async throws {
        let (viewModel, loadedAt) = try await offlineAfterLoadingTheList(id: "work")
        await viewModel.load()
        harness.monica.settings.unreachable = false
        harness.monica.settings.override = { request in
            request.url.path().hasSuffix("/vaults/work") ? .delayed(0.3, .failure(.cannotConnectToHost)) : nil
        }

        let reload = Task { await viewModel.load() }
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.state.staleSince == loadedAt)
        await reload.value

        #expect(viewModel.state.staleSince == loadedAt)
    }

    @Test func `with no copy, offline still says why`() async throws {
        let viewModel = try await signedIn(id: "work")
        harness.monica.settings.unreachable = true

        await viewModel.load()

        #expect(viewModel.state == .failed(.unreachable))
    }
}

private extension VaultUiState {
    var vaultName: String? {
        if case let .loaded(vault, _) = self {
            vault.name
        } else {
            nil
        }
    }
}
