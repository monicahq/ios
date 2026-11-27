import Foundation
@testable import Monica
import Testing

@MainActor
struct SessionManagerRenewalTests {
    @Test func `renews access once it expired, and the request succeeds`() async throws {
        let harness = Harness()
        try await harness.signIn()
        let before = try #require(harness.sessionManager.session)
        harness.clock.advance(by: 3600)

        _ = try await harness.sessionManager.authorizedGet("/api/v1/me")

        let after = try #require(harness.sessionManager.session)
        #expect(after.accessToken != before.accessToken)
        #expect(after.refreshToken != before.refreshToken)
        #expect(after.renewedAt == harness.clock.now)
        #expect(harness.store.read(.session, as: Session.self) == after)
        let renewal = try #require(harness.monica.requests.last { $0.url.path().hasSuffix("/oauth/token") })
        #expect(renewal.form == [
            "grant_type": "refresh_token",
            "client_id": before.clientID,
            "refresh_token": before.refreshToken,
            "scope": "api",
        ])
    }

    @Test func `does not renew access that is still valid`() async throws {
        let harness = Harness()
        try await harness.signIn()

        _ = try await harness.sessionManager.authorizedGet("/api/v1/me")

        #expect(harness.monica.tokenRequestCount == 1)
    }

    @Test func `twenty requests finding access expired renew it once`() async throws {
        let harness = Harness()
        try await harness.signIn()
        harness.clock.advance(by: 3600)
        let sessionManager = harness.sessionManager

        let requests = (0 ..< 20).map { _ in
            Task { try await sessionManager.authorizedGet("/api/v1/me") }
        }
        for request in requests {
            _ = await request.result
        }

        #expect(harness.monica.tokenRequestCount == 2)
        #expect(harness.sessionManager.session != nil)
    }

    @Test func `an unauthenticated answer renews once and retries once`() async throws {
        let harness = Harness()
        try await harness.signIn()
        let original = try #require(harness.sessionManager.session?.accessToken)
        harness.monica.settings.override = { request in
            request.headers["Authorization"] == "Bearer \(original)" ? .json(401, #"{"message":"Unauthenticated."}"#) : nil
        }

        _ = try await harness.sessionManager.authorizedGet("/api/v1/me")

        #expect(harness.monica.tokenRequestCount == 2)
        #expect(harness.sessionManager.session?.accessToken != original)
    }

    @Test func `still unauthenticated after a renewal ends the session instead of looping`() async throws {
        let harness = Harness()
        try await harness.signIn()
        harness.monica.settings.override = { request in
            request.url.path().hasSuffix("/api/v1/me") ? .json(401, #"{"message":"Unauthenticated."}"#) : nil
        }

        await #expect(throws: AuthError.sessionEnded) { _ = try await harness.sessionManager.authorizedGet("/api/v1/me") }
        #expect(harness.monica.tokenRequestCount == 2)
        #expect(harness.sessionManager.state == .signedOut(.ended))
    }

    @Test func `a refused renewal ends the session`() async throws {
        let harness = Harness()
        try await harness.signIn()
        harness.monica.settings.refusesRenewal = true
        harness.clock.advance(by: 3600)

        await #expect(throws: AuthError.sessionEnded) { _ = try await harness.sessionManager.authorizedGet("/api/v1/me") }
        #expect(harness.sessionManager.state == .signedOut(.ended))
        #expect(!harness.store.contains(.session))
    }

    @Test func `a renewal refused after 30 days unused means the session expired`() async throws {
        let harness = Harness()
        try await harness.signIn()
        harness.monica.settings.refusesRenewal = true
        harness.clock.advance(by: 31 * 24 * 3600)

        await #expect(throws: AuthError.sessionExpired) { _ = try await harness.sessionManager.authorizedGet("/api/v1/me") }
        #expect(harness.sessionManager.state == .signedOut(.expired))
    }

    @Test func `being offline when access must be renewed keeps the session`() async throws {
        let harness = Harness()
        try await harness.signIn()
        harness.monica.settings.unreachable = true
        harness.clock.advance(by: 3600)

        await #expect(throws: AuthError.unreachable) { _ = try await harness.sessionManager.authorizedGet("/api/v1/me") }
        #expect(harness.sessionManager.session != nil)
        #expect(harness.store.contains(.session))
    }

    @Test func `a server error during renewal keeps the session`() async throws {
        let harness = Harness()
        try await harness.signIn()
        harness.monica.settings.override = { request in
            request.url.path().hasSuffix("/oauth/token") ? .json(503, "maintenance") : nil
        }
        harness.clock.advance(by: 3600)

        await #expect(throws: AuthError.unexpectedAnswer) { _ = try await harness.sessionManager.authorizedGet("/api/v1/me") }
        #expect(harness.sessionManager.session != nil)
    }

    @Test func `not allowed is said without renewing or signing out`() async throws {
        let harness = Harness()
        try await harness.signIn()
        harness.monica.settings.override = { request in
            request.url.path().hasSuffix("/api/v1/me") ? .json(403, #"{"message":"Forbidden."}"#) : nil
        }

        await #expect(throws: AuthError.notAllowed) { _ = try await harness.sessionManager.authorizedGet("/api/v1/me") }
        #expect(harness.monica.tokenRequestCount == 1)
        #expect(harness.sessionManager.session != nil)
    }

    @Test func `a server error is said without signing out`() async throws {
        let harness = Harness()
        try await harness.signIn()
        harness.monica.settings.override = { request in
            request.url.path().hasSuffix("/api/v1/me") ? .json(500, "oops") : nil
        }

        await #expect(throws: AuthError.unexpectedAnswer) { _ = try await harness.sessionManager.authorizedGet("/api/v1/me") }
        #expect(harness.sessionManager.session != nil)
    }

    @Test func `a token renewed by somebody else is used as is`() async throws {
        let harness = Harness()
        try await harness.signIn()

        let token = try await harness.sessionManager.renew(after: "an older token")

        #expect(token == harness.sessionManager.session?.accessToken)
        #expect(harness.monica.tokenRequestCount == 1)
    }

    @Test func `refreshing the person picks up a new name`() async throws {
        let harness = Harness()
        try await harness.signIn()
        harness.monica.settings.meAfterSignIn = .json(200, """
        {"data":{"attributes":{"first_name":"Pam","last_name":"Beesly","email":"pam@example.com"}}}
        """)

        try await harness.sessionManager.refreshPerson()

        #expect(harness.sessionManager.session?.name == "Pam Beesly")
        #expect(harness.store.read(.session, as: Session.self)?.email == "pam@example.com")
    }

    @Test func `nothing is asked when signed out`() async {
        let harness = Harness()

        await #expect(throws: AuthError.sessionEnded) { _ = try await harness.sessionManager.authorizedGet("/api/v1/me") }
        #expect(harness.monica.requests.isEmpty)
    }
}
