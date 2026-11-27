import Foundation
import Observation

/// Why the person is signed out, when the app knows.
enum SignOutReason: Equatable {
    case loggedOut
    /// Unused for longer than a refresh token lives.
    case expired
    /// Ended elsewhere: from the web's security settings, or refused for another reason.
    case ended
    case instanceChanged
}

enum SessionState: Equatable {
    case signedOut(SignOutReason?)
    case signedIn(Session)
}

/// The one owner of the session: it starts and completes sign-in, stores the session in the
/// Keychain, renews its access, signs out, and tells the app whether the person is signed in. No
/// other type reads a token. It also owns the life of the offline copy: opened for a session,
/// erased whenever one ends, swept at launch (see `OfflineCopy`).
///
/// Main-actor isolated: the main actor is the lock that makes renewal single-flight (one stored
/// task that every caller awaits) and orders sign-in, sign-out and switching. `generation` changes
/// at each of those, so the result of anything started before is thrown away.
@MainActor
@Observable
final class SessionManager {
    private(set) var state: SessionState
    @ObservationIgnored private(set) var generation = 0

    @ObservationIgnored private let store: any SecretStore
    @ObservationIgnored private let configuration: URLSessionConfiguration
    @ObservationIgnored private let deviceName: String
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let offlineCopy: OfflineCopy
    @ObservationIgnored private var client: MonicaClient?
    @ObservationIgnored private var renewal: Task<Session, any Error>?
    @ObservationIgnored private var isRetryingRevocation = false

    init(
        store: any SecretStore,
        configuration: URLSessionConfiguration,
        deviceName: String,
        offlineCopy: OfflineCopy,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.configuration = configuration
        self.deviceName = deviceName
        self.offlineCopy = offlineCopy
        self.now = now
        state = store.read(.session, as: Session.self).map(SessionState.signedIn) ?? .signedOut(nil)
        // The sweep: nothing kept survives a session that is gone, or belongs to another one.
        if let session {
            offlineCopy.open(owner: session.copyOwner, now: now())
        } else {
            offlineCopy.sweep()
        }
    }

    var session: Session? {
        if case let .signedIn(session) = state {
            session
        } else {
            nil
        }
    }

    // MARK: Signing in

    /// Starts an attempt against `description`, replacing any previous one, and returns the page
    /// the browser opens.
    func startSignIn(_ description: InstanceDescription, isSignUp: Bool) throws(AuthError) -> URL {
        let pending = PendingSignIn(description: description, isSignUp: isSignUp, now: now())
        do {
            try store.write(pending, for: .pendingSignIn)
        } catch {
            throw .signInFailed
        }
        return pending.authorizationURL
    }

    /// Whether the attempt in progress, if any, is a sign up: a closed browser then means "waiting
    /// for the confirmation email" rather than "cancelled".
    var pendingSignInIsSignUp: Bool {
        store.read(.pendingSignIn, as: PendingSignIn.self)?.isSignUp ?? false
    }

    /// Forgets the attempt in progress: its answer, if it ever comes, is ignored.
    func forgetPendingSignIn() {
        store.delete(.pendingSignIn)
    }

    /// Handles an answer that came back to the app, from the browser sheet or from iOS opening
    /// the return address. Returns true once signed in, false when the answer is not for the
    /// current attempt and was ignored without contacting anybody.
    @discardableResult
    func complete(callback: URL, currentInstance: String) async throws(AuthError) -> Bool {
        guard callback.scheme == "com.monicahq.ios", callback.path() == "/oauth/callback",
              let pending = store.read(.pendingSignIn, as: PendingSignIn.self)
        else { return false }
        guard pending.instance == currentInstance else {
            store.delete(.pendingSignIn)
            return false
        }
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }
        // An answer for another attempt: refused, and the real one can still arrive.
        guard value("state") == pending.state else { throw .signInFailed }
        store.delete(.pendingSignIn)
        guard !pending.isExpired(at: now()) else { throw .signInExpired }
        if let error = value("error") {
            throw error == "access_denied" ? .denied : .signInFailed
        }
        guard let code = value("code"), !code.isEmpty else { throw .signInFailed }

        let generation = generation
        let client = MonicaClient(base: pending.instance, configuration: configuration)
        defer { client.invalidate() }
        let tokens = try await exchange(code, of: pending, with: client)
        let person = try await person(with: client, token: tokens.accessToken)
        guard generation == self.generation else { return false }

        let session = Session(
            instance: pending.instance,
            clientID: pending.clientID,
            scope: pending.scope,
            tokenEndpoint: pending.tokenEndpoint,
            revocationEndpoint: pending.revocationEndpoint,
            accessToken: tokens.accessToken,
            accessTokenExpiresAt: now().addingTimeInterval(tokens.expiresIn),
            refreshToken: tokens.refreshToken ?? "",
            renewedAt: now(),
            name: person.name,
            email: person.email,
            copyOwner: UUID()
        )
        do {
            try store.write(session, for: .session)
        } catch {
            throw .signInFailed
        }
        self.generation += 1
        offlineCopy.open(owner: session.copyOwner, now: now())
        state = .signedIn(session)
        return true
    }

    private func exchange(
        _ code: String,
        of pending: PendingSignIn,
        with client: MonicaClient
    ) async throws(AuthError) -> TokenResponse {
        let response = try await client.postForm(pending.tokenEndpoint, [
            ("grant_type", "authorization_code"),
            ("client_id", pending.clientID),
            ("redirect_uri", signInReturnAddress),
            ("code", code),
            ("code_verifier", pending.verifier),
            ("device_name", deviceName),
        ])
        guard response.status == 200 else {
            throw [400, 401].contains(response.status) ? .signInFailed : .unexpectedAnswer
        }
        guard let tokens = try? JSONDecoder().decode(TokenResponse.self, from: response.data),
              tokens.refreshToken != nil
        else { throw .unexpectedAnswer }
        return tokens
    }

    private func person(with client: MonicaClient, token: String) async throws(AuthError) -> Person {
        guard let url = client.url("/api/v1/me") else { throw .unexpectedAnswer }
        let response = try await client.get(url, token: token)
        guard response.status == 200 else {
            throw [401, 403].contains(response.status) ? .signInFailed : .unexpectedAnswer
        }
        guard let person = try? JSONDecoder().decode(MeResponse.self, from: response.data).data.attributes
        else { throw .unexpectedAnswer }
        return person
    }

    // MARK: Using the session

    /// Reloads who is signed in, so the home shows the name the web has now. Renews access first
    /// when needed.
    func refreshPerson() async throws(AuthError) {
        let data = try await authorizedGet("/api/v1/me")
        guard let person = try? JSONDecoder().decode(MeResponse.self, from: data).data.attributes else {
            throw .unexpectedAnswer
        }
        guard var session, person.name != session.name || person.email != session.email else { return }
        session.name = person.name
        session.email = person.email
        try? store.write(session, for: .session)
        state = .signedIn(session)
    }

    /// A GET on the API of the signed-in instance, for callers that only expect success: any other
    /// answer is an error.
    func authorizedGet(_ path: String) async throws(AuthError) -> Data {
        let response = try await authorized("GET", path)
        switch response.status {
        case 200 ..< 300: return response.data
        case 403: throw .notAllowed
        default: throw .unexpectedAnswer
        }
    }

    /// A request to the API of the signed-in instance. Renews access when it has expired, or once
    /// when the instance answers "not authenticated", and retries the request once with the new
    /// access. Returns the answer whatever its status (other than 401), so a repository can tell
    /// "not found" or "refused" from a failure.
    func authorized(_ method: String, _ path: String, json: Data? = nil) async throws(AuthError) -> MonicaClient.Response {
        guard let session else { throw .sessionEnded }
        let generation = generation
        let client = sessionClient(for: session)
        guard let url = client.url(path) else { throw .unexpectedAnswer }
        var token = session.needsRenewal(at: now()) ? try await renew(after: session.accessToken) : session.accessToken
        var response = try await client.send(method: method, url: url, json: json, token: token)
        if response.status == 401 {
            token = try await renew(after: token)
            response = try await client.send(method: method, url: url, json: json, token: token)
            if response.status == 401 {
                // Renewed and still refused: the session is over, and asking again would loop.
                if generation == self.generation {
                    endLocally(.ended)
                }
                throw .sessionEnded
            }
        }
        guard generation == self.generation else { throw .cancelled }
        offlineCopy.recordContact(at: now())
        return response
    }

    /// Renews access, once for every caller: if another caller already renewed since `staleToken`
    /// was read, its token is returned; if a renewal is running, it is awaited. A refused renewal
    /// ends the session; a network failure keeps it.
    func renew(after staleToken: String) async throws(AuthError) -> String {
        guard let session else { throw .sessionEnded }
        if session.accessToken != staleToken {
            return session.accessToken
        }
        if let renewal {
            do {
                return try await renewal.value.accessToken
            } catch {
                throw AuthError(error)
            }
        }
        let generation = generation
        let task = Task { try await self.requestRenewal(of: session) }
        renewal = task
        let result = await task.result
        if renewal == task {
            renewal = nil
        }
        guard generation == self.generation else { throw .sessionEnded }
        switch result {
        case let .success(renewed):
            try? store.write(renewed, for: .session)
            state = .signedIn(renewed)
            return renewed.accessToken
        case let .failure(error):
            let error = AuthError(error)
            if error == .sessionExpired {
                endLocally(.expired)
            } else if error == .sessionEnded {
                endLocally(.ended)
            }
            throw error
        }
    }

    private func requestRenewal(of session: Session) async throws -> Session {
        let response = try await sessionClient(for: session).postForm(session.tokenEndpoint, [
            ("grant_type", "refresh_token"),
            ("client_id", session.clientID),
            ("refresh_token", session.refreshToken),
            ("scope", session.scope),
        ])
        if [400, 401].contains(response.status) {
            // The app never sends two renewals at once, so a refused one means the session is over.
            throw now().timeIntervalSince(session.renewedAt) > Session.lifetime
                ? AuthError.sessionExpired : AuthError.sessionEnded
        }
        guard response.status == 200,
              let tokens = try? JSONDecoder().decode(TokenResponse.self, from: response.data)
        else { throw AuthError.unexpectedAnswer }
        var renewed = session
        renewed.accessToken = tokens.accessToken
        renewed.accessTokenExpiresAt = now().addingTimeInterval(tokens.expiresIn)
        renewed.refreshToken = tokens.refreshToken ?? session.refreshToken
        renewed.renewedAt = now()
        return renewed
    }

    private func sessionClient(for session: Session) -> MonicaClient {
        if let client, client.base == session.instance {
            return client
        }
        let client = MonicaClient(base: session.instance, configuration: configuration)
        self.client = client
        return client
    }

    /// Ends the session on this phone: requests in flight are cancelled, their results discarded,
    /// and the offline copy is erased. Every way a session ends goes through here.
    private func endLocally(_ reason: SignOutReason) {
        generation += 1
        renewal?.cancel()
        renewal = nil
        client?.invalidate()
        client = nil
        store.delete(.session)
        // Before saying so: the welcome screen never shows while the copy still exists.
        offlineCopy.erase()
        state = .signedOut(reason)
    }
}

extension SessionManager {
    // MARK: Signing out

    /// Signs this phone out: forgotten here at once, then the instance is told. When it cannot be
    /// reached, it is told later (`retryPendingRevocation`). Other phones stay signed in.
    func logOut(reason: SignOutReason = .loggedOut) async {
        store.delete(.pendingSignIn)
        guard let session else { return }
        endLocally(reason)
        let revocation = PendingRevocation(session: session, now: now())
        if await !revoke(revocation) {
            try? store.write(revocation, for: .pendingRevocation)
        }
    }

    /// Tells the instance about a logout it missed, if any.
    func retryPendingRevocation() async {
        guard !isRetryingRevocation,
              let revocation = store.read(.pendingRevocation, as: PendingRevocation.self)
        else { return }
        isRetryingRevocation = true
        defer { isRetryingRevocation = false }
        if revocation.isExpired(at: now()) {
            store.delete(.pendingRevocation)
        } else if await revoke(revocation) {
            store.delete(.pendingRevocation)
        }
    }

    /// Returns false only when the instance could not be reached, so trying again makes sense.
    private func revoke(_ revocation: PendingRevocation) async -> Bool {
        let client = MonicaClient(base: revocation.instance, configuration: configuration)
        defer { client.invalidate() }
        do {
            _ = try await client.postForm(revocation.revocationEndpoint, [
                ("token", revocation.refreshToken),
                ("token_type_hint", "refresh_token"),
                ("client_id", revocation.clientID),
            ])
            return true
        } catch {
            return !error.isNetwork
        }
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: TimeInterval

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}
