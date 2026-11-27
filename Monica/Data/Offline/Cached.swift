import Foundation

/// A value read from the offline copy, and when the instance last answered it: what a screen shows
/// at once, and the date of its "not up to date" line if the instance cannot be reached.
struct Cached<Value: Equatable & Sendable>: Equatable, Sendable {
    let value: Value
    let updatedAt: Date
}
