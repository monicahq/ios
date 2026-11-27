import Foundation
@testable import Monica
import Testing

@MainActor
struct SessionManagerLogOutTests {
    @Test func `logging out forgets the session and tells the instance`() async throws {
        let harness = Harness()
        try await harness.signIn()
        let session = try #require(harness.sessionManager.session)

        await harness.sessionManager.logOut()

        #expect(harness.sessionManager.state == .signedOut(.loggedOut))
        #expect(!harness.store.contains(.session))
        let revocation = try #require(harness.monica.requests.last)
        #expect(revocation.url.path().hasSuffix("/oauth/revoke"))
        #expect(revocation.form == ["token": session.refreshToken, "token_type_hint": "refresh_token", "client_id": session.clientID])
        #expect(!harness.store.contains(.pendingRevocation))
    }

    @Test func `logging out leaves no secret in the Keychain, even a sign-in in progress`() async throws {
        let harness = Harness()
        try await harness.signIn()
        _ = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: false)

        await harness.sessionManager.logOut()

        #expect(SecretKey.allCases.allSatisfy { !harness.store.contains($0) })
        #expect(harness.relaunched().session == nil)
    }

    @Test func `logging out offline forgets the session now and tells the instance later`() async throws {
        let harness = Harness()
        try await harness.signIn()
        harness.monica.settings.unreachable = true

        await harness.sessionManager.logOut()

        #expect(harness.sessionManager.state == .signedOut(.loggedOut))
        #expect(harness.store.contains(.pendingRevocation))

        harness.monica.settings.unreachable = false
        await harness.relaunched().retryPendingRevocation()

        #expect(harness.monica.requests.last?.url.path().hasSuffix("/oauth/revoke") == true)
        #expect(!harness.store.contains(.pendingRevocation))
    }

    @Test func `a logout still unheard of after 30 days is dropped`() async throws {
        let harness = Harness()
        try await harness.signIn()
        harness.monica.settings.unreachable = true
        await harness.sessionManager.logOut()
        harness.clock.advance(by: 31 * 24 * 3600)

        await harness.sessionManager.retryPendingRevocation()

        #expect(!harness.store.contains(.pendingRevocation))
    }

    @Test func `retrying while still offline keeps the logout to tell`() async throws {
        let harness = Harness()
        try await harness.signIn()
        harness.monica.settings.unreachable = true
        await harness.sessionManager.logOut()

        await harness.sessionManager.retryPendingRevocation()

        #expect(harness.store.contains(.pendingRevocation))
    }

    @Test func `logging out cancels a sign-in in progress`() async throws {
        let harness = Harness()
        _ = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: false)

        await harness.sessionManager.logOut()

        #expect(!harness.store.contains(.pendingSignIn))
    }

    @Test func `switching instance sends nothing of the first instance to the second`() async throws {
        let first = Harness()
        try await first.signIn()
        let session = try #require(first.sessionManager.session)
        let second = FakeMonica()
        // A request to the first instance is still in flight when the person switches.
        first.monica.settings.override = { request in
            if request.url.path().hasSuffix("/api/v1/me") {
                Thread.sleep(forTimeInterval: 0.2)
            }
            return nil
        }
        let inFlight = Task { try await first.sessionManager.authorizedGet("/api/v1/me") }
        try await Task.sleep(for: .milliseconds(50))

        first.repository.setURL(second.base)
        await first.sessionManager.logOut(reason: .instanceChanged)
        let result = await inFlight.result

        #expect(throws: AuthError.self) { try result.get() }
        #expect(first.sessionManager.state == .signedOut(.instanceChanged))
        #expect(first.monica.requests.last?.url.path().hasSuffix("/oauth/revoke") == true)
        let description = try await first.checker.check(base: second.base)
        let page = try first.sessionManager.startSignIn(description, isSignUp: false)
        try await first.sessionManager.complete(callback: Harness.callback(for: page), currentInstance: second.base)
        for request in second.requests {
            let sent = request.url.absoluteString + request.headers.values.joined() + request.form.values.joined()
            #expect(!sent.contains(session.accessToken))
            #expect(!sent.contains(session.refreshToken))
            #expect(!sent.contains("michael.scott"))
        }
        #expect(first.sessionManager.session?.instance == second.base)
    }
}
