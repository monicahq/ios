import Foundation
@testable import Monica
import SwiftData
import Testing

@MainActor
struct VaultRepositoryTests {
    private let harness = Harness()

    private func signedIn(with vaults: [FakeMonica.Vault] = []) async throws -> VaultRepository {
        harness.monica.settings.vaults = vaults
        try await harness.signIn()
        return harness.vaultRepository
    }

    private func numbered(_ count: Int) -> [FakeMonica.Vault] {
        (1 ... count).map { FakeMonica.Vault(id: "v\($0)", name: "Vault \($0)", isDefault: $0 == 1) }
    }

    private var listRequests: [FakeMonica.Request] {
        harness.monica.requests.filter { $0.method == "GET" && $0.url.path().hasSuffix("/api/v1/vaults") }
    }

    // MARK: Listing

    @Test func `an account without vaults has an empty list`() async throws {
        let repository = try await signedIn()

        #expect(try await repository.vaults().isEmpty)
        #expect(listRequests.count == 1)
    }

    @Test func `lists the vaults in the order the instance answers`() async throws {
        let repository = try await signedIn(with: FakeMonica.threeVaults)

        let vaults = try await repository.vaults()

        #expect(vaults.map(\.name) == ["Personal", "Family", "Work"])
        #expect(vaults.map(\.contactCount) == [25, 1, 0])
        #expect(vaults.map(\.isDefault) == [true, false, false])
        #expect(vaults.map(\.colour) == [.blue, .green, .ochre])
        #expect(vaults[0].description == "Friends and the people I meet.")
    }

    @Test(arguments: [(1, 1), (100, 1), (101, 2), (150, 2), (201, 3)])
    func `loads every page, a hundred at a time`(count: Int, pages: Int) async throws {
        let repository = try await signedIn(with: numbered(count))

        let vaults = try await repository.vaults()

        #expect(vaults.map(\.id) == numbered(count).map(\.id))
        #expect(listRequests.count == pages)
        let query = try #require(listRequests.last.flatMap { URLComponents(url: $0.url, resolvingAgainstBaseURL: false) }?.queryItems)
        #expect(query.contains(URLQueryItem(name: "per_page", value: "100")))
        #expect(query.contains(URLQueryItem(name: "page", value: "\(pages)")))
    }

    @Test func `stops at an empty page even if the total says more`() async throws {
        let repository = try await signedIn()
        harness.monica.settings.override = { request in
            guard request.url.path().hasSuffix("/api/v1/vaults") else { return nil }
            return .json(200, #"{"data":[],"meta":{"page":1,"per_page":100,"total":5}}"#)
        }

        #expect(try await repository.vaults().isEmpty)
        #expect(listRequests.count == 1)
    }

    // MARK: One vault

    @Test func `reads one vault by its id`() async throws {
        let repository = try await signedIn(with: FakeMonica.threeVaults)

        let vault = try await repository.vault(id: "work")

        #expect(vault.name == "Work")
        #expect(vault.description == "Dunder Mifflin, Scranton branch.")
    }

    @Test func `a vault that no longer exists is not found`() async throws {
        let repository = try await signedIn(with: FakeMonica.threeVaults)

        await #expect(throws: ApiError.notFound) { _ = try await repository.vault(id: "gone") }
    }

    // MARK: Creating

    @Test func `creates a vault with what was typed`() async throws {
        let repository = try await signedIn(with: FakeMonica.threeVaults)

        let vault = try await repository.create(NewVault(name: "Book club", description: "Readers", colour: .teal, makeDefault: true))

        #expect(vault.name == "Book club")
        #expect(vault.colour == .teal)
        #expect(vault.isDefault)
        let post = try #require(harness.monica.requests.last { $0.method == "POST" })
        let body = try #require(JSONSerialization.jsonObject(with: post.body) as? [String: AnyHashable])
        #expect(body == ["name": "Book club", "description": "Readers", "colour": "#2f7f86", "is_default": true])
        #expect(try await repository.vaults().last?.name == "Book club")
    }

    @Test func `the first vault becomes the default`() async throws {
        let repository = try await signedIn()

        let vault = try await repository.create(NewVault(name: "Personal", description: nil, colour: .blue, makeDefault: false))

        #expect(vault.isDefault)
    }

    @Test func `a refusal carries the instance's words`() async throws {
        let repository = try await signedIn(with: [FakeMonica.Vault(id: "p", name: "Personal", isDefault: true)])
        harness.monica.settings.vaultLimit = 1

        let message = "The free plan holds 1 vault, and this account already has it. Full access lifts the ceiling."
        await #expect(throws: ApiError.invalid(Refusal(message: message, fields: ["name": message]))) {
            _ = try await repository.create(NewVault(name: "Work", description: nil, colour: .blue, makeDefault: false))
        }
    }

    // MARK: Failures

    @Test(arguments: [
        (FakeMonica.Answer.json(403, #"{"message":"Forbidden."}"#), ApiError.failed(.notAllowed)),
        (.json(500, "<html>Oops</html>"), .failed(.unexpectedAnswer)),
        (.json(200, "not json"), .failed(.unexpectedAnswer)),
        (.json(422, "not json"), .failed(.unexpectedAnswer)),
        (.json(404, #"{"message":"Not found."}"#), .notFound),
        (.json(429, #"{"message":"Too Many Attempts."}"#), .failed(.unexpectedAnswer)),
        (.json(503, "maintenance"), .failed(.unexpectedAnswer)),
        (.json(200, #"{"data":[{"id":"a"}],"meta":{"total":1}}"#), .failed(.unexpectedAnswer)),
        (.json(401, #"{"message":"Unauthenticated."}"#), .failed(.sessionEnded)),
        (.failure(.notConnectedToInternet), .failed(.unreachable)),
        (.failure(.timedOut), .failed(.timeout)),
    ])
    func `failures say what went wrong`(answer: FakeMonica.Answer, error: ApiError) async throws {
        let repository = try await signedIn()
        harness.monica.settings.override = { request in
            request.url.path().contains("/api/v1/vaults") ? answer : nil
        }

        await #expect(throws: error) { _ = try await repository.vaults() }
    }

    @Test func `creating offline creates nothing and says so`() async throws {
        let repository = try await signedIn()
        harness.monica.settings.unreachable = true

        await #expect(throws: ApiError.failed(.unreachable)) {
            _ = try await repository.create(NewVault(name: "Work", description: nil, colour: .blue, makeDefault: false))
        }

        harness.monica.settings.unreachable = false
        #expect(try await repository.vaults().isEmpty)
    }

    @Test func `nothing is asked when signed out`() async {
        await #expect(throws: ApiError.failed(.sessionEnded)) { _ = try await harness.vaultRepository.vaults() }
    }

    // MARK: The offline copy

    private func cachedNames(_ repository: VaultRepository) -> [String]? {
        repository.cachedVaults()?.value.map(\.name)
    }

    @Test func `nothing is kept before the list was loaded`() async throws {
        let repository = try await signedIn(with: FakeMonica.threeVaults)

        #expect(repository.cachedVaults() == nil)
    }

    @Test func `the list loaded is kept, in its order, with when it was loaded`() async throws {
        let repository = try await signedIn(with: FakeMonica.threeVaults)
        harness.clock.advance(by: 60)

        let vaults = try await repository.vaults()

        let cached = try #require(repository.cachedVaults())
        #expect(cached.value == vaults)
        #expect(cached.updatedAt == harness.clock.now)
        #expect(cached.value.first?.updatedAt == Date(timeIntervalSince1970: 1_756_252_800))
    }

    @Test func `a vault answered twice is kept once, and leaves with it`() async throws {
        // Created while the list loaded, a vault on the edge of a page comes back on the next one.
        let repository = try await signedIn(with: [
            FakeMonica.Vault(id: "work", name: "Work"),
            FakeMonica.Vault(id: "work", name: "Work"),
        ])
        _ = try await repository.vaults()
        #expect(cachedNames(repository) == ["Work"])

        harness.monica.settings.vaults = []
        _ = try await repository.vaults()

        #expect(cachedNames(repository) == [])
    }

    @Test func `a new answer replaces the copy whole`() async throws {
        let repository = try await signedIn(with: FakeMonica.threeVaults)
        _ = try await repository.vaults()
        harness.monica.settings.vaults = [
            FakeMonica.Vault(id: "work", name: "Office", colour: "#9a3f2b"),
            FakeMonica.Vault(id: "new", name: "Book club"),
            FakeMonica.Vault(id: "personal", name: "Personal", isDefault: true),
        ]

        _ = try await repository.vaults()

        #expect(cachedNames(repository) == ["Office", "Book club", "Personal"])
        #expect(repository.cachedVaults()?.value.first?.colour == .rust)
    }

    @Test func `a vault with a change waiting is never overwritten by a refresh`() async throws {
        let repository = try await signedIn(with: FakeMonica.threeVaults)
        _ = try await repository.vaults()
        let context = try #require(harness.offlineCopy.context)
        let family = try #require(try context.fetch(FetchDescriptor<CachedVault>()).first { $0.serverID == "family" })
        family.syncState = .pendingUpdate
        family.name = "Family (edited offline)"
        harness.offlineCopy.save()
        harness.monica.settings.vaults.removeAll { $0.id == "family" }

        _ = try await repository.vaults()

        // A vault waiting to be sent keeps its place; the others follow the answer.
        #expect(Set(cachedNames(repository) ?? []) == ["Personal", "Work", "Family (edited offline)"])
        #expect(cachedNames(repository)?.firstIndex(of: "Personal") == 0)
    }

    @Test func `a failed load leaves the copy as it was`() async throws {
        let repository = try await signedIn(with: FakeMonica.threeVaults)
        _ = try await repository.vaults()
        let before = repository.cachedVaults()
        harness.monica.settings.unreachable = true
        harness.clock.advance(by: 60)

        _ = try? await repository.vaults()

        #expect(repository.cachedVaults() == before)
    }

    @Test func `the copy is read again after a relaunch`() async throws {
        let repository = try await signedIn(with: FakeMonica.threeVaults)
        _ = try await repository.vaults()

        let copy = harness.relaunchedCopy()
        let relaunched = harness.relaunched(copy: copy)
        let after = VaultRepository(sessionManager: relaunched, offlineCopy: copy, now: { harness.clock.now })

        #expect(cachedNames(after) == ["Personal", "Family", "Work"])
    }

    @Test func `nothing is kept once the session ended`() async throws {
        let repository = try await signedIn(with: FakeMonica.threeVaults)
        _ = try await repository.vaults()

        await harness.sessionManager.logOut()

        #expect(repository.cachedVaults() == nil)
    }

    @Test func `a vault of the list is kept on its own too`() async throws {
        let repository = try await signedIn(with: FakeMonica.threeVaults)
        _ = try await repository.vaults()

        let cached = try #require(repository.cachedVault(id: "work"))

        #expect(cached.value.name == "Work")
        #expect(cached.updatedAt == harness.clock.now)
        #expect(repository.cachedVault(id: "unknown") == nil)
    }

    @Test func `reading one vault updates it in place in the list`() async throws {
        let repository = try await signedIn(with: FakeMonica.threeVaults)
        _ = try await repository.vaults()
        harness.monica.settings.vaults[1].name = "Relatives"
        harness.clock.advance(by: 60)

        _ = try await repository.vault(id: "family")

        #expect(cachedNames(repository) == ["Personal", "Relatives", "Work"])
        #expect(repository.cachedVault(id: "family")?.updatedAt == harness.clock.now)
    }

    @Test func `a vault read on its own that the list did not hold comes last`() async throws {
        let repository = try await signedIn(with: FakeMonica.threeVaults)
        _ = try await repository.vaults()
        harness.monica.settings.vaults.append(FakeMonica.Vault(id: "new", name: "Book club"))

        _ = try await repository.vault(id: "new")

        #expect(cachedNames(repository) == ["Personal", "Family", "Work", "Book club"])
    }

    @Test func `a vault that no longer exists leaves the copy`() async throws {
        let repository = try await signedIn(with: FakeMonica.threeVaults)
        _ = try await repository.vaults()
        harness.monica.settings.goneVaultIDs = ["work"]

        await #expect(throws: ApiError.notFound) { _ = try await repository.vault(id: "work") }

        #expect(repository.cachedVault(id: "work") == nil)
        #expect(cachedNames(repository) == ["Personal", "Family"])
    }
}
