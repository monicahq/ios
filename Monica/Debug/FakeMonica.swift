#if DEBUG
    import AuthenticationServices
    import Foundation
    import Synchronization

    /// A Monica instance played in memory, for tests only (Debug builds; Release builds do not
    /// contain it). Unit tests create one per test on a host of their own and change what it
    /// answers; UI tests pick a scenario through `MONICA_UI_TEST_SERVER`, and the app then
    /// answers every host with it (`FakeMonica.forUITests()`).
    ///
    /// It answers the way the real instance does (see `specs/002-login-registration/contracts`):
    /// the status, the OAuth metadata, the token, revocation and `/api/v1/me` endpoints.
    final class FakeMonica: Sendable {
        struct Request: Sendable {
            let method: String
            let url: URL
            let headers: [String: String]
            let form: [String: String]
        }

        enum Answer: Sendable {
            case json(Int, String)
            case failure(URLError.Code)
            case redirect(String)
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
        }

        private struct State {
            var settings: Settings
            var requests: [Request] = []
            var meCount = 0
            var tokenCount = 0
        }

        private static let registry = Mutex<[String: FakeMonica]>([:])
        private static let wildcard = "*"

        let host: String
        let path: String
        private let state: Mutex<State>

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
            registry.withLock { $0[host] ?? $0[wildcard] }
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
            if settings.unreachable {
                return .failure(.cannotConnectToHost)
            }
            // Routed by the end of the path, so the UI tests' fake also plays an instance served
            // under a path; the instance address is what comes before the route.
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

        // MARK: UI tests

        /// How each UI test scenario differs from a compatible instance.
        private static let scenarios: [String: @Sendable (inout Settings) -> Void] = [
            "unreachable": { $0.unreachable = true },
            "notMonica": { $0.isMonica = false },
            "monicaTooOld": { $0.knowsTheIOSApp = false },
            "appTooOld": { $0.minimumIOSVersion = "999.0" },
            "registrationClosed": { $0.registrationEnabled = false },
            "renewalRefused": {
                $0.expiresIn = 1
                $0.refusesRenewal = true
            },
            "shortLived": { $0.expiresIn = 1 },
            "notAllowed": { $0.meAfterSignIn = .json(403, #"{"message":"Forbidden."}"#) },
            "offlineAfterSignIn": { $0.meAfterSignIn = .failure(.notConnectedToInternet) },
        ]

        /// The fake the app uses for UI tests, from the `MONICA_UI_TEST_SERVER` scenario, or nil
        /// when the app runs for real.
        static func forUITests() -> FakeMonica? {
            guard let scenario = ProcessInfo.processInfo.environment["MONICA_UI_TEST_SERVER"] else { return nil }
            var settings = Settings()
            scenarios[scenario]?(&settings)
            return FakeMonica(settings: settings, host: wildcard)
        }

        /// Stands in for the browser sheet in UI tests: answers as if the person allowed access,
        /// denied it or closed the sheet, from `MONICA_UI_TEST_BROWSER` (allow by default; slow
        /// allows after two seconds, so a test can see the attempt in progress).
        static func uiTestBrowser() -> Browser? {
            let environment = ProcessInfo.processInfo.environment
            guard environment["MONICA_UI_TEST_SERVER"] != nil else { return nil }
            let answer = environment["MONICA_UI_TEST_BROWSER"] ?? "allow"
            return { url in
                try await Task.sleep(for: .milliseconds(answer == "slow" ? 2000 : 300))
                let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first { $0.name == "state" }?.value ?? ""
                switch answer {
                case "cancel":
                    throw ASWebAuthenticationSessionError(.canceledLogin)
                case "deny":
                    return URL(string: "\(signInReturnAddress)?error=access_denied&state=\(state)") ?? url
                default:
                    return URL(string: "\(signInReturnAddress)?code=ui-test&state=\(state)") ?? url
                }
            }
        }
    }

    /// Routes requests to the fake of their host.
    final class FakeMonicaProtocol: URLProtocol {
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
            let answer = fake.answer(FakeMonica.Request(
                method: request.httpMethod ?? "GET",
                url: url,
                headers: request.allHTTPHeaderFields ?? [:],
                form: Self.form(of: request)
            ))
            switch answer {
            case let .failure(code):
                client?.urlProtocol(self, didFailWithError: URLError(code))
            case let .redirect(location):
                respond(url: url, status: 302, headers: ["Location": location], body: Data())
            case let .json(status, body):
                respond(url: url, status: status, headers: ["Content-Type": "application/json"], body: Data(body.utf8))
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

        /// The fields of a form post. URLSession hands the body to protocols as a stream.
        private static func form(of request: URLRequest) -> [String: String] {
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
            var components = URLComponents()
            components.percentEncodedQuery = String(bytes: body, encoding: .utf8)
            return Dictionary(
                (components.queryItems ?? []).map { ($0.name, $0.value ?? "") },
                uniquingKeysWith: { $1 }
            )
        }
    }
#endif
