import Foundation

/// What checking an instance learned: how the app signs in to it. Rebuilt at every check, never
/// stored as such.
struct InstanceDescription: Equatable, Sendable {
    var base: String
    var clientID: String
    var scope: String
    var registrationEnabled: Bool
    var minimumIOSVersion: String?
    var authorizationEndpoint: URL
    var tokenEndpoint: URL
    var revocationEndpoint: URL
}

/// Asks an instance whether the app can work with it, before its address is saved and before
/// every sign-in: Monica's status (is it Monica, does it know the iOS app, does it accept new
/// accounts) then its OAuth metadata (where to sign in). Every address comes from the instance;
/// only these two documents are at fixed places under its address.
struct InstanceChecker: Sendable {
    let configuration: URLSessionConfiguration
    let appVersion: String
    let allowsHTTP: Bool

    /// Normalises what the person typed, then checks the instance at that address.
    func check(draft: String) async throws(AuthError) -> InstanceDescription {
        let base = try normalizeInstanceURL(draft, allowsHTTP: allowsHTTP).get()
        return try await check(base: base)
    }

    func check(base: String) async throws(AuthError) -> InstanceDescription {
        let client = MonicaClient(base: base, configuration: configuration)
        defer { client.invalidate() }
        guard let statusURL = client.url("/api/v1/status"),
              let metadataURL = client.url("/.well-known/oauth-authorization-server"),
              let baseURL = URL(string: base)
        else { throw .invalidAddress }

        let statusResponse = try await client.get(statusURL)
        guard statusResponse.status == 200,
              let status = try? JSONDecoder().decode(Status.self, from: statusResponse.data),
              status.status == "ok"
        else { throw .notMonica }
        guard let mobile = status.mobile, mobile.apiVersion >= 1, mobile.knowsTheIOSApp else { throw .monicaTooOld }
        if let minimum = mobile.minimumIOSVersion, isVersion(appVersion, olderThan: minimum) == true {
            throw .appTooOld
        }

        let metadataResponse = try await client.get(metadataURL)
        guard metadataResponse.status == 200,
              let metadata = try? JSONDecoder().decode(Metadata.self, from: metadataResponse.data),
              metadata.issuer.trimmingSuffix("/") == base,
              metadata.codeChallengeMethods.contains("S256"),
              let authorization = metadata.authorizationEndpoint,
              let token = metadata.tokenEndpoint,
              let revocation = metadata.revocationEndpoint,
              [authorization, token, revocation].allSatisfy({ isUnder(baseURL, $0) })
        else { throw .noAppSignIn }

        return InstanceDescription(
            base: base,
            clientID: mobile.clientID,
            scope: mobile.scope,
            registrationEnabled: mobile.registrationEnabled,
            minimumIOSVersion: mobile.minimumIOSVersion,
            authorizationEndpoint: authorization,
            tokenEndpoint: token,
            revocationEndpoint: revocation
        )
    }

    /// Whether `endpoint` is on the instance's origin and under its path: a code or a token never
    /// goes anywhere else, even if the instance's metadata says so.
    private func isUnder(_ base: URL, _ endpoint: URL) -> Bool {
        guard origin(of: endpoint) == origin(of: base) else { return false }
        let basePath = base.path().trimmingSuffix("/")
        return basePath.isEmpty || endpoint.path() == basePath || endpoint.path().hasPrefix(basePath + "/")
    }
}

private struct Status: Decodable {
    let status: String
    let mobile: MobileStatus?
}

private struct MobileStatus: Decodable {
    let apiVersion: Int
    let clientID: String
    let scope: String
    let registrationEnabled: Bool
    let minimumIOSVersion: String?
    /// An instance that predates the iOS app has no `minimum_ios_version` at all (null means
    /// "every version"), and refuses the iOS return address: it is too old for the app.
    let knowsTheIOSApp: Bool

    enum CodingKeys: String, CodingKey {
        case apiVersion = "api_version"
        case clientID = "client_id"
        case scope
        case registrationEnabled = "registration_enabled"
        case minimumIOSVersion = "minimum_ios_version"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiVersion = try container.decode(Int.self, forKey: .apiVersion)
        clientID = try container.decode(String.self, forKey: .clientID)
        scope = try container.decode(String.self, forKey: .scope)
        registrationEnabled = try container.decode(Bool.self, forKey: .registrationEnabled)
        knowsTheIOSApp = container.contains(.minimumIOSVersion)
        minimumIOSVersion = try container.decodeIfPresent(String.self, forKey: .minimumIOSVersion)
    }
}

private struct Metadata: Decodable {
    let issuer: String
    let authorizationEndpoint: URL?
    let tokenEndpoint: URL?
    let revocationEndpoint: URL?
    let codeChallengeMethods: [String]

    enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case revocationEndpoint = "revocation_endpoint"
        case codeChallengeMethods = "code_challenge_methods_supported"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        issuer = try container.decode(String.self, forKey: .issuer)
        authorizationEndpoint = try container.decodeIfPresent(URL.self, forKey: .authorizationEndpoint)
        tokenEndpoint = try container.decodeIfPresent(URL.self, forKey: .tokenEndpoint)
        revocationEndpoint = try container.decodeIfPresent(URL.self, forKey: .revocationEndpoint)
        codeChallengeMethods = try container.decodeIfPresent([String].self, forKey: .codeChallengeMethods) ?? []
    }
}

extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        var value = Substring(self)
        while !suffix.isEmpty, value.hasSuffix(suffix) {
            value = value.dropLast(suffix.count)
        }
        return String(value)
    }
}
