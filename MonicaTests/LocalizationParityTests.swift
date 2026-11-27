import Foundation
import Testing

/// The parts of a String Catalog (`.xcstrings`) the tests read.
private struct Catalog: Decodable {
    struct Entry: Decodable {
        var localizations: [String: Localization]?
    }

    var sourceLanguage: String
    var strings: [String: Entry]
}

private struct Localization: Decodable {
    struct StringUnit: Decodable {
        var state: String
        var value: String
    }

    struct Variations: Decodable {
        var plural: [String: Localization]?
    }

    var stringUnit: StringUnit?
    var variations: Variations?

    /// The texts of this language: one, or one per plural form (zero, one, other...).
    var units: [String: StringUnit] {
        if let plural = variations?.plural {
            plural.compactMapValues(\.stringUnit)
        } else {
            stringUnit.map { ["": $0] } ?? [:]
        }
    }
}

/// Every language must have every string, with the same placeholders, so that a translation is
/// never forgotten in a pull request (constitution, principle VI).
struct LocalizationParityTests {
    private static let supportedLanguages = ["en", "fr"]

    /// The catalog is read from the source tree: the compiled app only holds the compiled tables.
    private static let catalogURL = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Monica/Resources/Localizable.xcstrings")

    private func catalog() throws -> Catalog {
        try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: Self.catalogURL))
    }

    private func placeholders(_ text: String) -> [String] {
        let pattern = /%(\d+\$)?[-#+ 0,(]*\d*(\.\d+)?(ll|l|h)?[@a-zA-Z%]/
        return text.matches(of: pattern).map { String($0.output.0) }.sorted()
    }

    @Test func `English is the source language`() throws {
        #expect(try catalog().sourceLanguage == "en")
    }

    /// iOS does not fall back to English for a key missing from a language's table: it shows the
    /// key itself. So even a text that is the same in every language (the product name) is listed
    /// in each of them.
    @Test(arguments: supportedLanguages)
    func `every string is translated`(language: String) throws {
        for (key, entry) in try catalog().strings {
            let units = entry.localizations?[language]?.units ?? [:]
            #expect(!units.isEmpty, "\(key) in \(language)")
            #expect(Set(units.keys) == Set((entry.localizations?["en"]?.units ?? [:]).keys), "\(key) in \(language)")
            for (form, unit) in units {
                #expect(unit.state == "translated", "\(key) \(form) in \(language)")
                #expect(!unit.value.isEmpty, "\(key) \(form) in \(language)")
            }
        }
    }

    @Test(arguments: supportedLanguages)
    func `every translation keeps the English placeholders`(language: String) throws {
        for (key, entry) in try catalog().strings {
            let english = entry.localizations?["en"]?.units ?? [:]
            let translated = entry.localizations?[language]?.units ?? [:]
            for (form, unit) in english {
                guard let translation = translated[form] else { continue }
                #expect(placeholders(unit.value) == placeholders(translation.value), "\(key) \(form) in \(language)")
            }
        }
    }
}
