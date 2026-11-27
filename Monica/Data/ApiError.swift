import Foundation

/// What a call to the API can end with besides success, as repositories report it. Kept apart from
/// `AuthError` because a refusal carries the instance's own words, not one of the app's messages.
enum ApiError: Error, Equatable {
    /// The request did not get an answer the app can use: network, ended session, not allowed...
    case failed(AuthError)
    /// The record was deleted, belongs to somebody else, or never existed (404).
    case notFound
    /// The instance refused what was sent (422), and said why.
    case invalid(Refusal)

    init(_ error: AuthError) {
        self = .failed(error)
    }
}

/// Why the instance refused a request: its general message, and the first message of each field it
/// names, written in the person's language by the instance.
struct Refusal: Equatable {
    let message: String
    let fields: [String: String]

    /// The refusal a 422 answer describes, or nil when the body is not one.
    init?(json data: Data) {
        guard let body = try? JSONDecoder().decode(Body.self, from: data) else { return nil }
        message = body.message
        fields = (body.errors ?? [:]).compactMapValues(\.first)
    }

    init(message: String, fields: [String: String] = [:]) {
        self.message = message
        self.fields = fields
    }

    private struct Body: Decodable {
        let message: String
        let errors: [String: [String]]?
    }
}
