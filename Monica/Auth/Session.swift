import Foundation

/// The person signed in on this phone: which instance issued the session, the tokens that open
/// it, and who they are. At most one, kept in the Keychain and replaced whole at every renewal.
struct Session: Codable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    /// A refresh token unused for this long has expired on the instance.
    static let lifetime: TimeInterval = 30 * 24 * 60 * 60

    var instance: String
    var clientID: String
    var scope: String
    var tokenEndpoint: URL
    var revocationEndpoint: URL
    var accessToken: String
    var accessTokenExpiresAt: Date
    var refreshToken: String
    var renewedAt: Date
    var name: String
    var email: String

    /// The access token is renewed a minute before the instance would refuse it.
    func needsRenewal(at now: Date) -> Bool {
        now >= accessTokenExpiresAt.addingTimeInterval(-60)
    }

    /// Tokens never reach a log.
    var description: String {
        "Session(instance: \(instance))"
    }

    var debugDescription: String {
        description
    }
}

/// A logout the instance has not heard about yet, because it could not be reached. Tried again at
/// the next launch and when the app comes back, and dropped once the token has expired anyway.
struct PendingRevocation: Codable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    var instance: String
    var revocationEndpoint: URL
    var clientID: String
    var refreshToken: String
    var createdAt: Date

    init(session: Session, now: Date) {
        instance = session.instance
        revocationEndpoint = session.revocationEndpoint
        clientID = session.clientID
        refreshToken = session.refreshToken
        createdAt = now
    }

    func isExpired(at now: Date) -> Bool {
        now.timeIntervalSince(createdAt) > Session.lifetime
    }

    var description: String {
        "PendingRevocation(instance: \(instance))"
    }

    var debugDescription: String {
        description
    }
}
