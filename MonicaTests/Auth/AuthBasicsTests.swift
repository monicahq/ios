import Foundation
@testable import Monica
import Testing

struct PKCETests {
    @Test func `the challenge of RFC 7636's example verifier is the RFC's`() {
        #expect(PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func `random values are 43 base64url characters, different each time`() {
        let values = (0 ..< 20).map { _ in PKCE.randomValue() }

        #expect(Set(values).count == 20)
        for value in values {
            #expect(value.count == 43)
            #expect(value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        }
    }
}

struct AppVersionTests {
    @Test(arguments: [
        ("1.0.0", "1.2.0", true),
        ("1.9.0", "1.10.0", true),
        ("1.10.0", "1.9.0", false),
        ("1.2", "1.2.0", false),
        ("2.0.0", "1.99.99", false),
        ("1.2.0", "1.2.0", false),
    ])
    func `compares versions number by number`(version: String, minimum: String, isOlder: Bool) {
        #expect(isVersion(version, olderThan: minimum) == isOlder)
    }

    @Test(arguments: ["", "latest", "1.x", "1..2", "-1.0"])
    func `ignores a minimum that is not a version`(minimum: String) {
        #expect(isVersion("1.0.0", olderThan: minimum) == nil)
    }
}

struct AuthErrorTests {
    @Test(arguments: [
        (URLError.Code.timedOut, AuthError.timeout),
        (.cannotFindHost, .unreachable),
        (.cannotConnectToHost, .unreachable),
        (.notConnectedToInternet, .unreachable),
        (.networkConnectionLost, .unreachable),
        (.serverCertificateUntrusted, .certificate),
        (.serverCertificateHasBadDate, .certificate),
        (.secureConnectionFailed, .certificate),
        (.cancelled, .cancelled),
        (.badServerResponse, .unexpectedAnswer),
    ])
    func `a network failure keeps its kind`(code: URLError.Code, error: AuthError) {
        #expect(AuthError(URLError(code)) == error)
    }

    @Test func `any other error is an unexpected answer`() {
        struct Other: Error {}

        #expect(AuthError(Other()) == .unexpectedAnswer)
        #expect(AuthError(AuthError.denied) == .denied)
    }

    @Test func `only network failures keep the session to try again`() {
        #expect(AuthError.unreachable.isNetwork)
        #expect(AuthError.timeout.isNetwork)
        #expect(!AuthError.unexpectedAnswer.isNetwork)
        #expect(!AuthError.sessionEnded.isNetwork)
    }

    @Test func `every error has its own message`() {
        let errors: [AuthError] = [
            .invalidAddress, .httpsRequired, .unreachable, .timeout, .certificate, .moved, .notMonica,
            .monicaTooOld, .appTooOld, .noAppSignIn, .registrationClosed, .cancelled, .signUpUnfinished,
            .denied, .signInFailed, .signInExpired, .sessionExpired, .sessionEnded, .notAllowed, .unexpectedAnswer,
        ]

        #expect(Set(errors.map(\.message.key)).count == errors.count)
    }
}

struct SecretsDescriptionTests {
    private func description() throws -> InstanceDescription {
        try InstanceDescription(
            base: "https://monica.example.com", clientID: "client", scope: "api", registrationEnabled: true,
            authorizationEndpoint: url("https://monica.example.com/oauth/authorize"),
            tokenEndpoint: url("https://monica.example.com/oauth/token"),
            revocationEndpoint: url("https://monica.example.com/oauth/revoke")
        )
    }

    @Test func `a pending sign-in never prints its state or verifier`() throws {
        let pending = try PendingSignIn(description: description(), isSignUp: false, now: Date())

        for text in [String(describing: pending), String(reflecting: pending), "\(pending)"] {
            #expect(!text.contains(pending.state))
            #expect(!text.contains(pending.verifier))
        }
    }

    private func session() throws -> Session {
        try Session(
            instance: "https://monica.example.com", clientID: "client", scope: "api",
            tokenEndpoint: url("https://monica.example.com/oauth/token"),
            revocationEndpoint: url("https://monica.example.com/oauth/revoke"),
            accessToken: "secret-access", accessTokenExpiresAt: Date(), refreshToken: "secret-refresh",
            renewedAt: Date(), name: "Pam", email: "pam@example.com", copyOwner: UUID()
        )
    }

    @Test func `a session keeps the owner of its offline copy when stored`() throws {
        let session = try session()

        let stored = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(session))

        #expect(stored == session)
        #expect(stored.copyOwner == session.copyOwner)
    }

    @Test func `a session never prints its tokens`() throws {
        let session = try session()
        let revocation = PendingRevocation(session: session, now: Date())

        for text in [
            String(describing: session),
            String(reflecting: session),
            String(describing: revocation),
            String(reflecting: revocation),
        ] {
            #expect(!text.contains("secret"))
        }
    }

    @Test func `the sign-in page asks for consent, and registration for a sign up`() throws {
        let logIn = try PendingSignIn(description: description(), isSignUp: false, now: Date())
        let signUp = try PendingSignIn(description: description(), isSignUp: true, now: Date())

        let items = try #require(URLComponents(url: logIn.authorizationURL, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        #expect(logIn.authorizationURL.absoluteString.hasPrefix("https://monica.example.com/oauth/authorize?"))
        #expect(query["response_type"] == "code")
        #expect(query["client_id"] == "client")
        #expect(query["redirect_uri"] == "com.monicahq.ios:/oauth/callback")
        #expect(query["scope"] == "api")
        #expect(query["state"] == logIn.state)
        #expect(query["code_challenge"] == PKCE.challenge(for: logIn.verifier))
        #expect(query["code_challenge_method"] == "S256")
        #expect(query["prompt"] == "consent")
        #expect(signUp.authorizationURL.absoluteString.contains("prompt=consent%20create"))
    }
}
