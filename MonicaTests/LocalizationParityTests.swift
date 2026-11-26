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

    var stringUnit: StringUnit?
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
            let unit = entry.localizations?[language]?.stringUnit
            #expect(unit?.state == "translated", "\(key) in \(language)")
            #expect(unit?.value.isEmpty == false, "\(key) in \(language)")
        }
    }

    @Test(arguments: supportedLanguages)
    func `every translation keeps the English placeholders`(language: String) throws {
        for (key, entry) in try catalog().strings {
            guard let english = entry.localizations?["en"]?.stringUnit?.value,
                  let translated = entry.localizations?[language]?.stringUnit?.value
            else { continue }
            #expect(placeholders(english) == placeholders(translated), "\(key) in \(language)")
        }
    }
}
