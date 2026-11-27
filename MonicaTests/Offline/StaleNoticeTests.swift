import Foundation
@testable import Monica
import Testing

struct StaleNoticeTests {
    struct Case: Sendable {
        let language: String
        let age: TimeInterval
        let text: String
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test(arguments: [
        Case(language: "en", age: 3 * 3600, text: "Not up to date. Last updated 3 hours ago."),
        Case(language: "fr", age: 3 * 3600, text: "Pas à jour. Mis à jour il y a 3 heures."),
        Case(language: "en", age: 60, text: "Not up to date. Last updated 1 minute ago."),
        Case(language: "fr", age: 2 * 24 * 3600, text: "Pas à jour. Mis à jour il y a 2 jours."),
    ])
    func `says since when, in the person's language`(example: Case) {
        let shown = staleNoticeText(since: now.addingTimeInterval(-example.age), now: now, locale: Locale(identifier: example.language))

        #expect(shown == example.text)
    }

    @Test func `announces the line when it appears, and when it goes`() {
        let since = now.addingTimeInterval(-3 * 3600)
        let english = Locale(identifier: "en")

        #expect(staleAnnouncement(since: since, now: now, locale: english) == "Not up to date. Last updated 3 hours ago.")
        #expect(staleAnnouncement(since: nil, now: now, locale: english) == "Up to date.")
        #expect(staleAnnouncement(since: nil, now: now, locale: Locale(identifier: "fr")) == "À jour.")
    }

    @Test func `says something else first in the same announcement`() {
        let shown = staleAnnouncement(
            since: now.addingTimeInterval(-60),
            prefix: "Your vaults could not be updated.",
            now: now,
            locale: Locale(identifier: "en")
        )

        #expect(shown == "Your vaults could not be updated. Not up to date. Last updated 1 minute ago.")
    }
}
