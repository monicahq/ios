import Foundation

/// Applies `attributes` to `part` inside `text`. Each language places the part where its grammar
/// wants it, so the range is found in the translated text rather than assumed.
func highlight(_ text: String, part: String, with attributes: AttributeContainer) -> AttributedString {
    var result = AttributedString(text)
    if !part.isEmpty, let range = result.range(of: part) {
        result[range].mergeAttributes(attributes)
    }
    return result
}
