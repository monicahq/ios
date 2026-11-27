import Foundation

/// The letter on a vault's square: the first character a person sees in its name, uppercased, as
/// the web does. A Swift `Character` is what a person sees as one letter, so an accented letter or
/// an emoji stays whole.
func vaultInitial(_ name: String, locale: Locale = .current) -> String {
    guard let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first else { return "" }
    return String(first).uppercased(with: locale)
}

/// Up to two letters for the account button: the first of the first two words that start with a
/// letter ("Jean-Pierre Martin" → "JM"). Nil when the name has none, so a person symbol is shown.
func personInitials(_ name: String, locale: Locale = .current) -> String? {
    let letters = name
        .split(whereSeparator: \.isWhitespace)
        .compactMap(\.first)
        .filter(\.isLetter)
        .prefix(2)
        .map(String.init)
    return letters.isEmpty ? nil : letters.joined().uppercased(with: locale)
}
