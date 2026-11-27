#if DEBUG
    import Foundation
    import Synchronization

    /// A Monica instance played in memory, for unit tests only (Debug builds; Release builds do
    /// not contain it). Tests create one per test on a host of their own and change what it
    /// answers.
    ///
    /// It answers the way the real instance does (see `specs/002-login-registration/contracts`):
    /// the status, the OAuth metadata, the token, revocation and `/api/v1/me` endpoints.
    final class FakeMonica: Sendable {
        struct Request: Sendable {
            let method: String
            let url: URL
            let headers: [String: String]
            let form: [String: String]
            /// The raw body, for JSON posts.
            var body = Data()
        }

        /// A vault the fake holds, as the API describes one.
        struct Vault: Sendable {
            var id: String
            var name: String
            var description: String?
            var colour = "#3f5fd0"
            var isDefault = false
            var contactCount = 0
        }

        enum Answer: Sendable {
            case json(Int, String)
            case failure(URLError.Code)
            case redirect(String)
            /// The answer, given after a while: to see a screen while it waits.
            indirect case delayed(TimeInterval, Answer)
        }

        struct Settings: Sendable {
            var isMonica = true
            var hasMobile = true
            var knowsTheIOSApp = true
            var registrationEnabled = true
            var minimumIOSVersion: String?
            /// What the metadata says the issuer is; nil means the instance address.
            var issuer: String?
            var challengeMethods = ["S256"]
            /// Where the metadata says the endpoints are; nil means under the instance address.
            var endpointBase: String?
            var unreachable = false
            var expiresIn = 3600
            var refusesRenewal = false
            /// What `/api/v1/me` answers after the first time (the sign-in): nil means the person.
            var meAfterSignIn: Answer?
            /// Checked before everything else; nil to answer normally.
            var override: (@Sendable (Request) -> Answer?)?
            /// The account's vaults, in their arranged order. Every account starts with none.
            var vaults: [Vault] = []
            /// How many vaults the plan allows; nil for no ceiling.
            var vaultLimit: Int?
            /// Vaults the list shows but that answer 404 when read: deleted meanwhile.
            var goneVaultIDs: Set<String> = []
            /// The list of vaults fails once it has answered this many times (offline afterwards).
            var vaultListFailsAfter: Int?
            /// How long the list of vaults takes to answer.
            var vaultListDelay: TimeInterval = 0
        }

        /// What the fake holds and counts. Internal for its extensions in other files.
        struct State {
            var settings: Settings
            var requests: [Request] = []
            var meCount = 0
            var tokenCount = 0
            var vaultListCount = 0
        }

        private static let registry = Mutex<[String: FakeMonica]>([:])

        let host: String
        let path: String
        let state: Mutex<State>

        /// A fake on a host of its own (`<uuid>.monica.test`), so tests running at the same time
        /// never share one.
        init(path: String = "", settings: Settings = Settings(), host: String = "\(UUID().uuidString.lowercased()).monica.test") {
            self.host = host
            self.path = path
            state = Mutex(State(settings: settings))
            Self.registry.withLock { $0[host] = self }
        }

        /// The instance address, as a person would save it.
        var base: String {
            "https://\(host)\(path)"
        }

        /// A network configuration whose requests reach the fakes instead of the network.
        static var configuration: URLSessionConfiguration {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [FakeMonicaProtocol.self]
            return configuration
        }

        var settings: Settings {
            get { state.withLock { $0.settings } }
            set { state.withLock { $0.settings = newValue } }
        }

        /// Every request received, in order.
        var requests: [Request] {
            state.withLock { $0.requests }
        }

        /// How many token requests (exchanges and renewals) were received.
        var tokenRequestCount: Int {
            state.withLock { $0.tokenCount }
        }

        static func fake(for host: String) -> FakeMonica? {
            registry.withLock { $0[host] }
        }

        func answer(_ request: Request) -> Answer {
            let (settings, meCount) = state.withLock { state in
                state.requests.append(request)
                if request.url.path().hasSuffix("/api/v1/me") {
                    state.meCount += 1
                }
                if request.url.path().hasSuffix("/oauth/token") {
                    state.tokenCount += 1
                }
                return (state.settings, state.meCount)
            }
            if let answer = settings.override?(request) {
                return answer
            }
            if let answer = vaultsOrUnreachable(request, settings: settings) {
                return answer
            }
            // Routed by the end of the path, so the fake also plays an instance served under a
            // path; the instance address is what comes before the route.
            let routes = ["/api/v1/status", "/.well-known/oauth-authorization-server", "/oauth/token", "/oauth/revoke", "/api/v1/me"]
            let fullPath = request.url.path()
            let route = routes.first { fullPath.hasSuffix($0) } ?? fullPath
            var components = URLComponents()
            components.scheme = request.url.scheme
            components.host = request.url.host()
            components.port = request.url.port
            let base = (components.string ?? "") + fullPath.dropLast(route.count)
            switch (request.method, route) {
            case ("GET", "/api/v1/status"):
                return status(settings)
            case ("GET", "/.well-known/oauth-authorization-server"):
                return metadata(settings, base: base)
            case ("POST", "/oauth/token"):
                return token(settings, form: request.form)
            case ("POST", "/oauth/revoke"):
                return .json(200, "")
            case ("GET", "/api/v1/me"):
                return me(settings, request: request, count: meCount)
            default:
                return .json(404, "<html>Not found</html>")
            }
        }

        private func me(_ settings: Settings, request: Request, count: Int) -> Answer {
            guard request.headers["Authorization"]?.hasPrefix("Bearer ") == true else {
                return .json(401, #"{"message":"Unauthenticated."}"#)
            }
            if count > 1, let answer = settings.meAfterSignIn {
                return answer
            }
            return .json(200, """
            {"data":{"type":"user","id":"1","attributes":{"first_name":"Michael","last_name":"Scott",\
            "email":"michael.scott@dundermifflin.com","name_order":"given_first"}}}
            """)
        }

        private func status(_ settings: Settings) -> Answer {
            guard settings.isMonica else { return .json(200, "<html>Hello</html>") }
            guard settings.hasMobile else {
                return .json(200, #"{"status":"ok","version":"5.2.0","instance":"monica.test"}"#)
            }
            let minimum = settings.minimumIOSVersion.map { "\"\($0)\"" } ?? "null"
            let ios = settings.knowsTheIOSApp ? #","minimum_ios_version":\#(minimum)"# : ""
            return .json(200, """
            {"status":"ok","version":"5.3.0","instance":"monica.test","mobile":{"api_version":1,\
            "client_id":"0198f6a4-7c2e-7d3b-9a61-5e0b4c8d2f17","scope":"api",\
            "registration_enabled":\(settings.registrationEnabled),"minimum_android_version":null\(ios)}}
            """)
        }

        private func metadata(_ settings: Settings, base: String) -> Answer {
            let endpoints = settings.endpointBase ?? base
            let methods = settings.challengeMethods.map { "\"\($0)\"" }.joined(separator: ",")
            return .json(200, """
            {"issuer":"\(settings.issuer ?? base)","authorization_endpoint":"\(endpoints)/oauth/authorize",\
            "token_endpoint":"\(endpoints)/oauth/token","revocation_endpoint":"\(endpoints)/oauth/revoke",\
            "code_challenge_methods_supported":[\(methods)],"scopes_supported":["mcp:use"]}
            """)
        }

        private func token(_ settings: Settings, form: [String: String]) -> Answer {
            let grant = form["grant_type"]
            if grant == "refresh_token", settings.refusesRenewal {
                return .json(400, #"{"error":"invalid_grant"}"#)
            }
            guard grant == "authorization_code" ? form["code_verifier"] != nil : form["refresh_token"] != nil else {
                return .json(400, #"{"error":"invalid_request"}"#)
            }
            let suffix = UUID().uuidString.prefix(8)
            return .json(200, """
            {"token_type":"Bearer","expires_in":\(settings.expiresIn),"access_token":"access-\(suffix)",\
            "refresh_token":"refresh-\(suffix)"}
            """)
        }
    }

    /// Routes requests to the fake of their host. Unchecked: URL loading hands a protocol from one
    /// of its threads to another by design, and a delayed answer finishes on another queue.
    final class FakeMonicaProtocol: URLProtocol, @unchecked Sendable {
        override static func canInit(with _: URLRequest) -> Bool {
            true
        }

        override static func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            guard let url = request.url, let fake = FakeMonica.fake(for: url.host() ?? "") else {
                client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
                return
            }
            let body = Self.body(of: request)
            let answer = fake.answer(FakeMonica.Request(
                method: request.httpMethod ?? "GET",
                url: url,
                headers: request.allHTTPHeaderFields ?? [:],
                form: request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded"
                    ? Self.form(from: body) : [:],
                body: body
            ))
            respond(url: url, answer: answer)
        }

        private func respond(url: URL, answer: FakeMonica.Answer) {
            switch answer {
            case let .failure(code):
                client?.urlProtocol(self, didFailWithError: URLError(code))
            case let .redirect(location):
                respond(url: url, status: 302, headers: ["Location": location], body: Data())
            case let .json(status, body):
                respond(url: url, status: status, headers: ["Content-Type": "application/json"], body: Data(body.utf8))
            case let .delayed(seconds, answer):
                DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { [self] in
                    respond(url: url, answer: answer)
                }
            }
        }

        override func stopLoading() {}

        private func respond(url: URL, status: Int, headers: [String: String], body: Data) {
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else {
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }

        /// The fields of a form post.
        private static func form(from body: Data) -> [String: String] {
            var components = URLComponents()
            components.percentEncodedQuery = String(bytes: body, encoding: .utf8)
            return Dictionary(
                (components.queryItems ?? []).map { ($0.name, $0.value ?? "") },
                uniquingKeysWith: { $1 }
            )
        }

        /// The body of a request. URLSession hands it to protocols as a stream, readable once.
        private static func body(of request: URLRequest) -> Data {
            var body = request.httpBody ?? Data()
            if body.isEmpty, let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    guard count > 0 else { break }
                    body.append(contentsOf: buffer[0 ..< count])
                }
            }
            return body
        }
    }
#endif
