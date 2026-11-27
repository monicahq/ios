import Foundation
@testable import Monica
import Testing

@MainActor
struct VaultsViewModelTests {
    private let harness = Harness()

    private func signedIn(with vaults: [FakeMonica.Vault] = FakeMonica.threeVaults) async throws -> VaultsViewModel {
        harness.monica.settings.vaults = vaults
        try await harness.signIn()
        return VaultsViewModel(repository: harness.vaultRepository)
    }

    private func names(_ state: VaultsUiState) -> [String]? {
        if case let .loaded(vaults) = state.content {
            vaults.map(\.name)
        } else {
            nil
        }
    }

    @Test func `starts loading`() async throws {
        let viewModel = try await signedIn()

        #expect(viewModel.state == VaultsUiState(content: .loading))
        #expect(!viewModel.state.hasVaults)
    }

    @Test func `shows the vaults`() async throws {
        let viewModel = try await signedIn()

        await viewModel.load()

        #expect(names(viewModel.state) == ["Personal", "Family", "Work"])
        #expect(viewModel.state.hasVaults)
        #expect(!viewModel.state.isRefreshing)
    }

    @Test func `an account without vaults shows the empty state`() async throws {
        let viewModel = try await signedIn(with: [])

        await viewModel.load()

        #expect(viewModel.state.content == .loaded([]))
        #expect(!viewModel.state.hasVaults)
    }

    @Test func `a first load that fails says why`() async throws {
        let viewModel = try await signedIn()
        harness.monica.settings.vaultListFailsAfter = 0

        await viewModel.load()

        #expect(viewModel.state.content == .failed(.unreachable))
    }

    @Test func `trying again loads the list`() async throws {
        let viewModel = try await signedIn()
        harness.monica.settings.vaultListFailsAfter = 0
        await viewModel.load()
        harness.monica.settings.vaultListFailsAfter = nil

        await viewModel.tryAgain()

        #expect(names(viewModel.state) == ["Personal", "Family", "Work"])
    }

    @Test func `reloading shows what changed on the web`() async throws {
        let viewModel = try await signedIn()
        await viewModel.load()
        harness.monica.settings.vaults[2].name = "Office"

        await viewModel.load()

        #expect(names(viewModel.state) == ["Personal", "Family", "Office"])
    }

    @Test func `a reload that fails keeps the list and says it could not be updated`() async throws {
        let viewModel = try await signedIn()
        harness.monica.settings.vaultListFailsAfter = 1
        await viewModel.load()

        await viewModel.load()

        #expect(names(viewModel.state) == ["Personal", "Family", "Work"])
        #expect(viewModel.state.refreshFailed)
        #expect(!viewModel.state.isRefreshing)
    }

    @Test func `the message goes away when dismissed, or at the next successful load`() async throws {
        let viewModel = try await signedIn()
        harness.monica.settings.vaultListFailsAfter = 1
        await viewModel.load()
        await viewModel.load()

        viewModel.dismissRefreshMessage()
        #expect(!viewModel.state.refreshFailed)

        await viewModel.load()
        harness.monica.settings.vaultListFailsAfter = nil
        await viewModel.load()
        #expect(!viewModel.state.refreshFailed)
    }

    @Test func `a reload is shown as refreshing while it runs`() async throws {
        let viewModel = try await signedIn()
        await viewModel.load()
        harness.monica.settings.vaultListDelay = 0.3

        let reload = Task { await viewModel.load() }
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.state.isRefreshing)
        await reload.value

        #expect(!viewModel.state.isRefreshing)
    }

    @Test func `an ended session says nothing here`() async throws {
        let viewModel = try await signedIn()
        harness.monica.settings.refusesRenewal = true
        harness.clock.advance(by: 3600)

        await viewModel.load()

        #expect(viewModel.state.content == .loading)
        #expect(harness.sessionManager.state == .signedOut(.ended))
    }

    @Test func `an answer that is not a list is an unexpected answer`() async throws {
        let viewModel = try await signedIn()
        harness.monica.settings.override = { request in
            request.url.path().hasSuffix("/api/v1/vaults") ? .json(404, "{}") : nil
        }

        await viewModel.load()

        #expect(viewModel.state.content == .failed(.unexpectedAnswer))
    }
}
