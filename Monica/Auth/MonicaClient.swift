import Foundation
import Synchronization

/// Talks to one Monica instance. Every rule that keeps tokens at home is enforced here, at the
/// lowest layer, so no caller can break it:
/// - a bearer token is attached only to requests for the instance's own origin;
/// - redirects are never followed (a `3xx` is "the instance moved"), so a token never follows one;
/// - the session has no cookies, no cache and no stored credentials.
final class MonicaClient: Sendable {
    struct Response: Sendable {
        let status: Int
        let data: Data
    }

    /// The instance address (`https://example.com/monica`), without a trailing slash.
    let base: String
    private let baseOrigin: String?
    fileprivate let session: URLSession
    /// URLSession raises an exception, which crashes the app, when a task is created after it was
    /// invalidated: a request still on its way when the session ended must fail instead.
    fileprivate let isInvalidated = Mutex(false)

    /// `configuration` is `.ephemeral` in the app; tests and UI tests add a stub protocol to it.
    init(base: String, configuration: URLSessionConfiguration) {
        self.base = base
        baseOrigin = URL(string: base).flatMap(origin(of:))
        let configuration = configuration.copy() as? URLSessionConfiguration ?? .ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
    }

    /// The address of an API path such as `/api/v1/status`, under the instance address.
    func url(_ path: String) -> URL? {
        URL(string: base + path)
    }

    func get(_ url: URL, token: String? = nil) async throws(AuthError) -> Response {
        try await send(method: "GET", url: url, json: nil, token: token)
    }

    /// A JSON post, as the API's create endpoints expect.
    func postJSON(_ url: URL, body: Data, token: String?) async throws(AuthError) -> Response {
        try await send(method: "POST", url: url, json: body, token: token)
    }

    /// A request to the API: JSON answers, and a JSON body when there is one.
    func send(method: String, url: URL, json: Data?, token: String?) async throws(AuthError) -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = json
        }
        return try await send(request, token: token)
    }

    /// A form post, as OAuth token and revocation endpoints expect.
    func postForm(_ url: URL, _ fields: [(String, String)]) async throws(AuthError) -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        request.httpBody = fields
            .map { name, value in
                "\(name)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
            }
            .joined(separator: "&")
            .data(using: .utf8)
        return try await send(request, token: nil)
    }

    /// Stops every request in flight and refuses new ones: used when the session it belongs to
    /// ends, so nothing started for it can finish.
    func invalidate() {
        isInvalidated.withLock { isInvalidated in
            if !isInvalidated {
                isInvalidated = true
                session.invalidateAndCancel()
            }
        }
    }

    private func send(_ request: URLRequest, token: String?) async throws(AuthError) -> Response {
        var request = request
        if let token, let url = request.url, origin(of: url) == baseOrigin {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await load(request)
        } catch {
            throw AuthError(error)
        }
        guard let http = response as? HTTPURLResponse else { throw .unexpectedAnswer }
        if (300 ..< 400).contains(http.statusCode) {
            throw .moved
        }
        return Response(status: http.statusCode, data: data)
    }
}

extension MonicaClient {
    /// Creates the task under the lock, so `invalidate()` cannot slip in between the check and the
    /// creation.
    private func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = isInvalidated.withLock { isInvalidated in
                isInvalidated ? nil : session.dataTask(with: request) { data, response, error in
                    if let data, let response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: error ?? URLError(.badServerResponse))
                    }
                }
            }
            guard let task else {
                continuation.resume(throwing: AuthError.cancelled)
                return
            }
            task.resume()
        }
    }
}

/// Answers every redirect with "do not follow": the `3xx` reaches the client as it is.
private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
