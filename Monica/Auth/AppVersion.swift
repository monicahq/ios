import Foundation

/// The version of the app, as the App Store shows it (`1.2.0`).
let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

/// Whether `version` is older than `minimum`, comparing numbers component by component, so
/// `1.10.0` is newer than `1.9.0` and `1.2` equals `1.2.0`. Nil when either is not a version, in
/// which case the instance's minimum is ignored rather than locking the person out.
func isVersion(_ version: String, olderThan minimum: String) -> Bool? {
    func components(_ value: String) -> [Int]? {
        let parts = value.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.compactMap { Int($0) }
        return parts.isEmpty || numbers.count != parts.count || numbers.contains { $0 < 0 } ? nil : numbers
    }
    guard let lhs = components(version), let rhs = components(minimum) else { return nil }
    for index in 0 ..< max(lhs.count, rhs.count) {
        let left = index < lhs.count ? lhs[index] : 0
        let right = index < rhs.count ? rhs[index] : 0
        if left != right {
            return left < right
        }
    }
    return false
}
