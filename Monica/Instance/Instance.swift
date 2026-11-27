import Foundation

/// The Monica instance the app talks to until the person chooses another one.
let defaultInstanceURL = "https://app.monicahq.com"

// Whether this build may talk to an instance over plain `http`. Only Debug builds may, for a
// Monica running on the developer's machine: the App Store build talks to instances over HTTPS
// only, so tokens never travel in clear text.
#if DEBUG
    let allowsHTTPInstances = true
#else
    let allowsHTTPInstances = false
#endif

/// The address of an instance as people read it: without the scheme and the trailing slash, but
/// with the port and the path, since self-hosted instances often need them to be told apart.
func instanceHost(_ url: String) -> String {
    var host = Substring(url.trimmingCharacters(in: .whitespacesAndNewlines))
    if let scheme = host.range(of: "://") {
        host = host[scheme.upperBound...]
    }
    while host.hasSuffix("/") {
        host = host.dropLast()
    }
    return String(host)
}

/// Turns what a person typed into the address to store, or the reason it cannot be used. Empty
/// means the default instance; a missing scheme means `https://`. Plain `http` is refused unless
/// `allowsHTTP`, with its own reason so the person is told to use HTTPS.
func normalizeInstanceURL(_ input: String, allowsHTTP: Bool) -> Result<String, AuthError> {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return .success(defaultInstanceURL)
    }
    if trimmed.contains(where: \.isWhitespace) {
        return .failure(.invalidAddress)
    }
    var url = Substring(trimmed.contains("://") ? trimmed : "https://\(trimmed)")
    while url.hasSuffix("/") {
        url = url.dropLast()
    }
    guard let components = URLComponents(string: String(url)),
          let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
          let host = components.host, !host.isEmpty,
          components.user == nil, components.password == nil
    else { return .failure(.invalidAddress) }
    if scheme == "http", !allowsHTTP {
        return .failure(.httpsRequired)
    }
    return .success(String(url))
}

/// The origin of `url` (scheme, host and port), the unit tokens are confined to. Two spellings of
/// the same origin (uppercase host, explicit default port) give the same value.
func origin(of url: URL) -> String? {
    guard let scheme = url.scheme?.lowercased(), let host = url.host()?.lowercased() else { return nil }
    let port = url.port ?? (scheme == "https" ? 443 : scheme == "http" ? 80 : -1)
    return "\(scheme)://\(host):\(port)"
}
