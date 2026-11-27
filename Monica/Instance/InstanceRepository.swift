import Foundation

/// The instance the person chose, kept on the device. Source of truth for the instance address.
///
/// Synchronous: `UserDefaults` keeps its values in memory and writes them to disk in the
/// background, so reading and saving one short string does not block the main actor.
@MainActor
final class InstanceRepository {
    private static let urlKey = "instance_url"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The saved address, or `defaultInstanceURL` when the person never chose one.
    var url: String {
        defaults.string(forKey: Self.urlKey) ?? defaultInstanceURL
    }

    /// Saves `url`, which must already be normalised (see `normalizeInstanceURL`).
    func setURL(_ url: String) {
        defaults.set(url, forKey: Self.urlKey)
    }
}
