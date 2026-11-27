import Foundation

/// The Monica instance the app talks to until the person chooses another one.
let defaultInstanceURL = "https://app.monicahq.com"

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

/// Turns what a person typed into the address to store, or nil when it is not an address the app
/// can use. Empty means the default instance; a missing scheme means `https://`. Plain `http` is
/// accepted because self-hosted instances on a home network often have no certificate.
func normalizeInstanceURL(_ input: String) -> String? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return defaultInstanceURL
    }
    if trimmed.contains(where: \.isWhitespace) {
        return nil
    }
    var url = Substring(trimmed.contains("://") ? trimmed : "https://\(trimmed)")
    while url.hasSuffix("/") {
        url = url.dropLast()
    }
    guard let components = URLComponents(string: String(url)),
          let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
          let host = components.host, !host.isEmpty
    else { return nil }
    return String(url)
}
