import Foundation
@testable import Monica
import Testing

struct InstanceTests {
    @Test func `the default instance is Monica's hosted service`() {
        #expect(defaultInstanceURL == "https://app.monicahq.com")
    }

    @Test func `host removes the https scheme`() {
        #expect(instanceHost("https://app.monicahq.com") == "app.monicahq.com")
    }

    @Test func `host removes the http scheme`() {
        #expect(instanceHost("http://monica.example.org") == "monica.example.org")
    }

    @Test func `host removes the trailing slash`() {
        #expect(instanceHost("https://app.monicahq.com/") == "app.monicahq.com")
    }

    @Test func `host keeps the port and the path`() {
        #expect(instanceHost("http://localhost:8000/monica/") == "localhost:8000/monica")
    }

    @Test func `host ignores surrounding spaces`() {
        #expect(instanceHost("  https://app.monicahq.com  ") == "app.monicahq.com")
    }

    @Test func `host of an address without scheme is the address itself`() {
        #expect(instanceHost("app.monicahq.com") == "app.monicahq.com")
    }
}

struct NormalizeInstanceURLTests {
    private func normalize(_ input: String, allowsHTTP: Bool = false) -> Result<String, AuthError> {
        normalizeInstanceURL(input, allowsHTTP: allowsHTTP)
    }

    @Test func `keeps a complete https address`() {
        #expect(normalize("https://monica.example.com") == .success("https://monica.example.com"))
    }

    @Test func `refuses plain http, asking for https`() {
        #expect(normalize("http://192.168.1.10:8080/monica") == .failure(.httpsRequired))
    }

    @Test func `accepts plain http when the build allows it`() {
        #expect(normalize("http://192.168.1.10:8080/monica", allowsHTTP: true) == .success("http://192.168.1.10:8080/monica"))
    }

    @Test func `adds https when the scheme is missing`() {
        #expect(normalize("monica.example.com") == .success("https://monica.example.com"))
    }

    @Test func `removes the trailing slashes`() {
        #expect(normalize("https://monica.example.com//") == .success("https://monica.example.com"))
    }

    @Test func `ignores surrounding spaces`() {
        #expect(normalize("  https://monica.example.com \n") == .success("https://monica.example.com"))
    }

    @Test(arguments: ["", "   "])
    func `an empty address means the default instance`(input: String) {
        #expect(normalize(input) == .success(defaultInstanceURL))
    }

    @Test(arguments: [
        "not an address", "ftp://monica.example.com", "https://", "monica example.com",
        "https://pam:secret@monica.example.com",
    ])
    func `refuses what is not a web address with a host`(input: String) {
        #expect(normalize(input) == .failure(.invalidAddress))
    }
}

struct OriginTests {
    @Test func `the same origin whatever the spelling`() throws {
        #expect(try origin(of: url("https://Monica.Example.com/oauth")) == origin(of: url("https://monica.example.com:443/x")))
    }

    @Test func `another port, scheme or host is another origin`() throws {
        let base = try origin(of: url("https://monica.example.com"))
        #expect(try origin(of: url("https://monica.example.com:8443")) != base)
        #expect(try origin(of: url("http://monica.example.com")) != base)
        #expect(try origin(of: url("https://monica.example.com.evil.test")) != base)
    }
}
