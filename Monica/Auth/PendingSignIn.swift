import Foundation

/// Where the instance sends the person back to the app after signing in. Registered on every
/// Monica for the mobile client, and declared by the app in its Info.plist.
let signInReturnAddress = "com.monicahq.ios:/oauth/callback"

/// One sign-in attempt in progress, kept in the Keychain from the moment the browser opens until
/// its answer arrives, so an answer that comes later (the link of a confirmation email, opened in
/// Safari after the app was quit) still completes it. Used once; expires after an hour.
struct PendingSignIn: Codable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    static let lifetime: TimeInterval = 60 * 60

    var instance: String
    var clientID: String
    var scope: String
    var authorizationEndpoint: URL
    var tokenEndpoint: URL
    var revocationEndpoint: URL
    var state: String
    var verifier: String
    var isSignUp: Bool
    var createdAt: Date

    init(description: InstanceDescription, isSignUp: Bool, now: Date) {
        instance = description.base
        clientID = description.clientID
        scope = description.scope
        authorizationEndpoint = description.authorizationEndpoint
        tokenEndpoint = description.tokenEndpoint
        revocationEndpoint = description.revocationEndpoint
        state = PKCE.randomValue()
        verifier = PKCE.randomValue()
        self.isSignUp = isSignUp
        createdAt = now
    }

    func isExpired(at now: Date) -> Bool {
        now.timeIntervalSince(createdAt) > Self.lifetime || now < createdAt.addingTimeInterval(-60)
    }

    /// The page the browser opens: the instance's sign-in page, or its registration page for
    /// Sign up, asking for consent every time.
    var authorizationURL: URL {
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)
        let existing = components?.queryItems ?? []
        components?.queryItems = existing + [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: signInReturnAddress),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: PKCE.challenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: isSignUp ? "consent create" : "consent"),
        ]
        return components?.url ?? authorizationEndpoint
    }

    /// The state and the verifier never reach a log.
    var description: String {
        "PendingSignIn(instance: \(instance), isSignUp: \(isSignUp))"
    }

    var debugDescription: String {
        description
    }
}
