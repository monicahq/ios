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
