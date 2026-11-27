import Foundation
@testable import Monica
import Testing

/// A store of its own for each test, so tests never see each other's values. A real
/// `UserDefaults` rather than a fake: it already keeps values in memory, and a protocol in front
/// of it would only exist for the tests.
func temporaryDefaults() -> UserDefaults {
    let suite = "MonicaTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite) ?? .standard
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

@MainActor
struct InstanceRepositoryTests {
    @Test func `is the default instance until the person chooses one`() {
        let repository = InstanceRepository(defaults: temporaryDefaults())

        #expect(repository.url == defaultInstanceURL)
    }

    @Test func `returns the saved address`() {
        let repository = InstanceRepository(defaults: temporaryDefaults())

        repository.setURL("https://monica.example.com")

        #expect(repository.url == "https://monica.example.com")
    }

    @Test func `keeps the address for the next launch`() {
        let defaults = temporaryDefaults()
        InstanceRepository(defaults: defaults).setURL("https://monica.example.com")

        let nextLaunch = InstanceRepository(defaults: defaults)

        #expect(nextLaunch.url == "https://monica.example.com")
    }
}
