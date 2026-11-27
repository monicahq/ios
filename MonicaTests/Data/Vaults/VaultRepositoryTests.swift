import Foundation
@testable import Monica
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

    @Test func `nothing is asked when signed out`() async {
        await #expect(throws: ApiError.failed(.sessionEnded)) { _ = try await harness.vaultRepository.vaults() }
    }
}
