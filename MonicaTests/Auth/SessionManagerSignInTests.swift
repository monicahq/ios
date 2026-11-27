import Foundation
@testable import Monica
import Testing

@MainActor
struct SessionManagerSignInTests {
    @Test func `starts signed out with an empty Keychain`() {
        #expect(Harness().sessionManager.state == .signedOut(nil))
    }

    @Test func `signs in with the answer of the instance`() async throws {
        let harness = Harness()

        try await harness.signIn()

        let session = try #require(harness.sessionManager.session)
        #expect(session.instance == harness.monica.base)
        #expect(session.name == "Michael Scott")
        #expect(session.email == "michael.scott@dundermifflin.com")
        #expect(session.accessTokenExpiresAt == harness.clock.now.addingTimeInterval(3600))
        #expect(harness.store.read(.session, as: Session.self) == session)
        #expect(!harness.store.contains(.pendingSignIn))
    }

    @Test func `exchanges the code with the verifier, the return address and the device name`() async throws {
        let harness = Harness()
        let page = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: false)
        let pending = try #require(harness.store.read(.pendingSignIn, as: PendingSignIn.self))

        try await harness.sessionManager.complete(callback: Harness.callback(for: page), currentInstance: harness.monica.base)

        let exchange = try #require(harness.monica.requests.first { $0.url.path().hasSuffix("/oauth/token") })
        #expect(exchange.form == [
            "grant_type": "authorization_code",
            "client_id": "0198f6a4-7c2e-7d3b-9a61-5e0b4c8d2f17",
            "redirect_uri": "com.monicahq.ios:/oauth/callback",
            "code": "the-code",
            "code_verifier": pending.verifier,
            "device_name": "iPhone · iOS 26.1",
        ])
    }

    @Test func `stays signed in after a relaunch`() async throws {
        let harness = Harness()
        try await harness.signIn()

        #expect(harness.relaunched().state == harness.sessionManager.state)
    }

    @Test func `a new attempt replaces the previous one`() async throws {
        let harness = Harness()
        let first = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: false)
        _ = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: true)

        await #expect(throws: AuthError.signInFailed) {
            try await harness.sessionManager.complete(callback: Harness.callback(for: first), currentInstance: harness.monica.base)
        }
        #expect(harness.sessionManager.pendingSignInIsSignUp)
    }

    @Test func `an answer with another state is refused, and the real one still works`() async throws {
        let harness = Harness()
        let page = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: false)

        await #expect(throws: AuthError.signInFailed) {
            try await harness.sessionManager.complete(
                callback: url("\(signInReturnAddress)?code=stolen&state=forged"),
                currentInstance: harness.monica.base
            )
        }
        try await harness.sessionManager.complete(callback: Harness.callback(for: page), currentInstance: harness.monica.base)

        #expect(harness.sessionManager.session != nil)
        #expect(harness.monica.tokenRequestCount == 1)
    }

    @Test func `an answer without an attempt in progress is ignored without contacting anybody`() async throws {
        let harness = Harness()

        let signedIn = try await harness.sessionManager.complete(
            callback: url("\(signInReturnAddress)?code=x&state=y"),
            currentInstance: harness.monica.base
        )

        #expect(!signedIn)
        #expect(harness.monica.requests.isEmpty)
    }

    @Test func `an answer is used once`() async throws {
        let harness = Harness()
        let page = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: false)
        let callback = try Harness.callback(for: page)
        try await harness.sessionManager.complete(callback: callback, currentInstance: harness.monica.base)

        let again = try await harness.sessionManager.complete(callback: callback, currentInstance: harness.monica.base)

        #expect(!again)
        #expect(harness.monica.tokenRequestCount == 1)
    }

    @Test func `an answer for another instance is ignored and the attempt forgotten`() async throws {
        let harness = Harness()
        let page = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: false)
        let requestsBefore = harness.monica.requests.count

        let signedIn = try await harness.sessionManager.complete(
            callback: Harness.callback(for: page),
            currentInstance: "https://another.test"
        )

        #expect(!signedIn)
        #expect(harness.monica.requests.count == requestsBefore)
        #expect(!harness.store.contains(.pendingSignIn))
    }

    @Test func `an address that is not the return address is ignored`() async throws {
        let harness = Harness()
        let page = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: false)
        let state = try #require(URLComponents(url: page, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "state" }?.value)

        let signedIn = try await harness.sessionManager.complete(
            callback: url("com.monicahq.ios:/other?code=x&state=\(state)"),
            currentInstance: harness.monica.base
        )

        #expect(!signedIn)
        #expect(harness.store.contains(.pendingSignIn))
    }

    @Test func `an attempt older than an hour has expired`() async throws {
        let harness = Harness()
        let page = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: true)
        harness.clock.advance(by: 3601)

        await #expect(throws: AuthError.signInExpired) {
            try await harness.sessionManager.complete(callback: Harness.callback(for: page), currentInstance: harness.monica.base)
        }
    }

    @Test func `an answer that arrives after a relaunch within the hour signs in`() async throws {
        let harness = Harness()
        let page = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: true)
        harness.clock.advance(by: 50 * 60)
        let relaunched = harness.relaunched()

        try await relaunched.complete(callback: Harness.callback(for: page), currentInstance: harness.monica.base)

        #expect(relaunched.session != nil)
    }

    @Test func `access denied on the consent page is said as such`() async throws {
        let harness = Harness()
        let page = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: false)

        await #expect(throws: AuthError.denied) {
            try await harness.sessionManager.complete(
                callback: Harness.callback(for: page, query: "error=access_denied"),
                currentInstance: harness.monica.base
            )
        }
        #expect(harness.monica.tokenRequestCount == 0)
    }

    @Test func `another error from the instance is a failed sign-in`() async throws {
        let harness = Harness()
        let page = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: false)

        await #expect(throws: AuthError.signInFailed) {
            try await harness.sessionManager.complete(
                callback: Harness.callback(for: page, query: "error=invalid_scope"),
                currentInstance: harness.monica.base
            )
        }
    }

    @Test func `a refused code is a failed sign-in, and nothing is stored`() async throws {
        let harness = Harness()
        harness.monica.settings.override = { request in
            request.url.path().hasSuffix("/oauth/token") ? .json(400, #"{"error":"invalid_request"}"#) : nil
        }

        await #expect(throws: AuthError.signInFailed) { try await harness.signIn() }
        #expect(harness.sessionManager.state == .signedOut(nil))
        #expect(!harness.store.contains(.session))
    }

    @Test func `an instance that cannot be reached for the exchange says so`() async throws {
        let harness = Harness()
        let page = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: false)
        harness.monica.settings.unreachable = true

        await #expect(throws: AuthError.unreachable) {
            try await harness.sessionManager.complete(callback: Harness.callback(for: page), currentInstance: harness.monica.base)
        }
    }

    @Test func `the profile must load before the person is signed in`() async throws {
        let harness = Harness()
        harness.monica.settings.override = { request in
            request.url.path().hasSuffix("/api/v1/me") ? .json(500, "oops") : nil
        }

        await #expect(throws: AuthError.unexpectedAnswer) { try await harness.signIn() }
        #expect(harness.sessionManager.session == nil)
    }

    @Test func `a Keychain that refuses the session fails the sign-in`() async throws {
        let harness = Harness(store: FakeSecretStore(failsWrites: true))

        await #expect(throws: AuthError.signInFailed) {
            _ = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: false)
        }
    }

    @Test func `forgetting the attempt ignores its answer`() async throws {
        let harness = Harness()
        let page = try await harness.sessionManager.startSignIn(harness.description(), isSignUp: false)

        harness.sessionManager.forgetPendingSignIn()

        #expect(try await !harness.sessionManager.complete(callback: Harness.callback(for: page), currentInstance: harness.monica.base))
    }

    @Test func `the name follows the order the person chose`() {
        let person = Person(firstName: "Michael", lastName: "Scott", email: "m@example.com", nameOrder: "family_first")

        #expect(person.name == "Scott Michael")
    }
}
