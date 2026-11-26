import Foundation
@testable import Monica
import Testing

struct HighlightTests {
    private let style = AttributeContainer().link(URL(filePath: "/"))

    private func highlighted(_ text: AttributedString) -> [String] {
        text.runs.filter { $0.link != nil }.map { String(text[$0.range].characters) }
    }

    @Test func `styles the part where it appears in the text`() {
        let result = highlight("Instance: app.monicahq.com", part: "app.monicahq.com", with: style)

        #expect(String(result.characters) == "Instance: app.monicahq.com")
        #expect(highlighted(result) == ["app.monicahq.com"])
        #expect(result.runs.first?.link == nil)
    }

    @Test func `follows the part when a language moves it`() {
        let result = highlight("app.monicahq.com est l'instance", part: "app.monicahq.com", with: style)

        #expect(highlighted(result) == ["app.monicahq.com"])
        #expect(result.runs.first?.link != nil)
    }

    @Test func `leaves the text unstyled when the part is missing`() {
        let result = highlight("Instance", part: "app.monicahq.com", with: style)

        #expect(String(result.characters) == "Instance")
        #expect(highlighted(result).isEmpty)
    }

    @Test func `leaves the text unstyled when the part is empty`() {
        #expect(highlighted(highlight("Instance: ", part: "", with: style)).isEmpty)
    }
}
