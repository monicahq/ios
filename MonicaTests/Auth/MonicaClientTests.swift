import Foundation
@testable import Monica
import Testing

struct MonicaClientTests {
    private let monica = FakeMonica()

    private func client(base: String? = nil) -> MonicaClient {
        MonicaClient(base: base ?? monica.base, configuration: FakeMonica.configuration)
    }

    @Test func `builds addresses under the instance address, path included`() throws {
        let client = client(base: "https://example.com/monica")

        #expect(try client.url("/api/v1/status") == url("https://example.com/monica/api/v1/status"))
    }

    @Test func `sends the token to its own instance`() async throws {
        let client = client()

        _ = try await client.get(url("\(monica.base)/api/v1/me"), token: "secret")

        #expect(monica.requests.last?.headers["Authorization"] == "Bearer secret")
    }

    @Test func `never sends the token to another origin`() async throws {
        let other = FakeMonica()
        let client = client()

        _ = try await client.get(url("\(other.base)/api/v1/me"), token: "secret")

        #expect(other.requests.count == 1)
        #expect(other.requests.last?.headers["Authorization"] == nil)
    }

    @Test func `a redirect is not followed and means the instance moved`() async throws {
        let other = FakeMonica()
        monica.settings.override = { [other] _ in .redirect("\(other.base)/api/v1/me") }
        let client = client()

        await #expect(throws: AuthError.moved) {
            _ = try await client.get(url("\(monica.base)/api/v1/me"), token: "secret")
        }
        #expect(other.requests.isEmpty)
    }

    @Test func `posts forms with every character escaped`() async throws {
        let client = client()

        _ = try await client.postForm(url("\(monica.base)/oauth/revoke"), [("token", "a+b&c=d é"), ("client_id", "id")])

        #expect(monica.requests.last?.form == ["token": "a+b&c=d é", "client_id": "id"])
        #expect(monica.requests.last?.headers["Authorization"] == nil)
    }

    @Test func `posts JSON with its headers and the token to its own instance`() async throws {
        let client = client()
        let body = Data(#"{"name":"Family"}"#.utf8)

        _ = try await client.postJSON(url("\(monica.base)/api/v1/vaults"), body: body, token: "secret")

        let request = try #require(monica.requests.last)
        #expect(request.method == "POST")
        #expect(request.body == body)
        #expect(request.headers["Content-Type"] == "application/json")
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.headers["Authorization"] == "Bearer secret")
    }

    @Test func `never posts the token to another origin`() async throws {
        let other = FakeMonica()
        let client = client()

        _ = try await client.postJSON(url("\(other.base)/api/v1/vaults"), body: Data("{}".utf8), token: "secret")

        #expect(other.requests.last?.headers["Authorization"] == nil)
    }

    @Test func `a get sends no body`() async throws {
        let client = client()

        _ = try await client.get(url("\(monica.base)/api/v1/status"))

        #expect(monica.requests.last?.method == "GET")
        #expect(monica.requests.last?.body.isEmpty == true)
        #expect(monica.requests.last?.headers["Content-Type"] == nil)
    }

    @Test func `a network failure keeps its kind`() async throws {
        monica.settings.unreachable = true
        let client = client()

        await #expect(throws: AuthError.unreachable) {
            _ = try await client.get(url("\(monica.base)/api/v1/status"))
        }
    }

    @Test func `nothing goes out once invalidated`() async throws {
        let client = client()
        client.invalidate()

        await #expect(throws: AuthError.self) {
            _ = try await client.get(url("\(monica.base)/api/v1/status"))
        }
        #expect(monica.requests.isEmpty)
    }
}
