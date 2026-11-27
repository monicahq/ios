import CryptoKit
import Foundation

/// Proof Key for Code Exchange (RFC 7636): the secret that proves the app exchanging a sign-in
/// code is the one that asked for it, since the app cannot hold a client secret.
enum PKCE {
    /// A fresh random value for a verifier or a state: 32 bytes from the system's cryptographically
    /// secure generator, base64url-encoded (43 characters).
    static func randomValue() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0 ..< 32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return base64URL(Data(bytes))
    }

    /// The S256 challenge sent with the authorization request for `verifier`.
    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    /// Base64url without padding, as OAuth expects.
    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
