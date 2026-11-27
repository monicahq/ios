import Foundation
@testable import Monica
import Testing

struct ApiErrorTests {
    @Test func `a refusal keeps the message and the first message of each field`() throws {
        let body = Data("""
        {"message":"The name is too long.","errors":{"name":["The name is too long.","Second"],"colour":["Unknown colour."]}}
        """.utf8)

        let refusal = try #require(Refusal(json: body))

        #expect(refusal.message == "The name is too long.")
        #expect(refusal.fields == ["name": "The name is too long.", "colour": "Unknown colour."])
    }

    @Test func `a refusal without field errors has no fields`() throws {
        let refusal = try #require(Refusal(json: Data(#"{"message":"No."}"#.utf8)))

        #expect(refusal == Refusal(message: "No."))
    }

    @Test func `a body that is not a refusal is not one`() {
        #expect(Refusal(json: Data("<html>Oops</html>".utf8)) == nil)
    }

    @Test func `an auth error stands for a failure`() {
        #expect(ApiError(.unreachable) == .failed(.unreachable))
    }
}
