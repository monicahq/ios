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
