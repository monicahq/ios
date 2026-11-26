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
    @Test func `keeps a complete https address`() {
        #expect(normalizeInstanceURL("https://monica.example.com") == "https://monica.example.com")
    }

    @Test func `accepts plain http for home servers`() {
        #expect(normalizeInstanceURL("http://192.168.1.10:8080/monica") == "http://192.168.1.10:8080/monica")
    }

    @Test func `adds https when the scheme is missing`() {
        #expect(normalizeInstanceURL("monica.example.com") == "https://monica.example.com")
    }

    @Test func `removes the trailing slashes`() {
        #expect(normalizeInstanceURL("https://monica.example.com//") == "https://monica.example.com")
    }

    @Test func `ignores surrounding spaces`() {
        #expect(normalizeInstanceURL("  https://monica.example.com \n") == "https://monica.example.com")
    }

    @Test(arguments: ["", "   "])
    func `an empty address means the default instance`(input: String) {
        #expect(normalizeInstanceURL(input) == defaultInstanceURL)
    }

    @Test(arguments: ["not an address", "ftp://monica.example.com", "https://", "monica example.com"])
    func `refuses what is not a web address with a host`(input: String) {
        #expect(normalizeInstanceURL(input) == nil)
    }
}
