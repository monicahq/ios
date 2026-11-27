import Foundation
@testable import Monica
import Testing

struct InstanceCheckerTests {
    private func checker(appVersion: String = "1.0.0", allowsHTTP: Bool = false) -> InstanceChecker {
        InstanceChecker(configuration: FakeMonica.configuration, appVersion: appVersion, allowsHTTP: allowsHTTP)
    }

    @Test func `describes a compatible instance`() async throws {
        let monica = FakeMonica()

        let description = try await checker().check(draft: monica.host)

        #expect(try description == InstanceDescription(
            base: monica.base,
            clientID: "0198f6a4-7c2e-7d3b-9a61-5e0b4c8d2f17",
            scope: "api",
            registrationEnabled: true,
            minimumIOSVersion: nil,
            authorizationEndpoint: url("\(monica.base)/oauth/authorize"),
            tokenEndpoint: url("\(monica.base)/oauth/token"),
            revocationEndpoint: url("\(monica.base)/oauth/revoke")
        ))
    }

    @Test func `works with an instance served under a path`() async throws {
        let monica = FakeMonica(path: "/monica")

        let description = try await checker().check(draft: monica.base + "/")

        #expect(description.base == monica.base)
        #expect(try description.tokenEndpoint == url("\(monica.base)/oauth/token"))
    }

    @Test func `says whether new accounts are accepted`() async throws {
        let monica = FakeMonica(settings: .init(registrationEnabled: false))

        #expect(try await checker().check(base: monica.base).registrationEnabled == false)
    }

    @Test func `accepts an app as new as the instance asks`() async throws {
        let monica = FakeMonica(settings: .init(minimumIOSVersion: "1.2.0"))

        #expect(try await checker(appVersion: "1.2.0").check(base: monica.base).minimumIOSVersion == "1.2.0")
    }

    @Test func `refuses an address the app cannot use without contacting anybody`() async {
        await #expect(throws: AuthError.invalidAddress) { try await checker().check(draft: "not an address") }
        await #expect(throws: AuthError.httpsRequired) { try await checker().check(draft: "http://monica.test") }
    }

    private func expect(_ error: AuthError, from settings: FakeMonica.Settings, appVersion: String = "1.0.0") async {
        let monica = FakeMonica(settings: settings)

        await #expect(throws: error) { try await checker(appVersion: appVersion).check(base: monica.base) }
    }

    @Test func `refuses what is not Monica`() async {
        await expect(.notMonica, from: .init(isMonica: false))
    }

    @Test func `refuses a Monica that does not know the mobile apps`() async {
        await expect(.monicaTooOld, from: .init(hasMobile: false))
    }

    @Test func `refuses a Monica that knows Android but not iOS`() async {
        await expect(.monicaTooOld, from: .init(knowsTheIOSApp: false))
    }

    @Test func `asks for a newer app when the instance requires one`() async {
        await expect(.appTooOld, from: .init(minimumIOSVersion: "1.10.0"), appVersion: "1.9.0")
    }

    @Test func `refuses an instance whose issuer is another address`() async {
        await expect(.noAppSignIn, from: .init(issuer: "https://elsewhere.test"))
    }

    @Test func `refuses an instance without S256`() async {
        await expect(.noAppSignIn, from: .init(challengeMethods: ["plain"]))
    }

    @Test func `refuses sign-in addresses on another origin`() async {
        await expect(.noAppSignIn, from: .init(endpointBase: "https://evil.test"))
    }

    @Test func `refuses sign-in addresses outside the instance path`() async {
        let monica = FakeMonica(path: "/monica")
        monica.settings.endpointBase = "https://\(monica.host)/other"

        await #expect(throws: AuthError.noAppSignIn) { try await checker().check(base: monica.base) }
    }

    @Test func `says when the instance cannot be reached`() async {
        await expect(.unreachable, from: .init(unreachable: true))
    }

    @Test func `says when the instance moved`() async {
        let monica = FakeMonica()
        monica.settings.override = { _ in .redirect("https://elsewhere.test/api/v1/status") }

        await #expect(throws: AuthError.moved) { try await checker().check(base: monica.base) }
    }

    @Test func `refuses metadata it cannot read`() async {
        let monica = FakeMonica()
        monica.settings.override = { request in
            request.url.path().hasSuffix("oauth-authorization-server") ? .json(200, "{}") : nil
        }

        await #expect(throws: AuthError.noAppSignIn) { try await checker().check(base: monica.base) }
    }

    // MARK: Trailing slashes

    @Test(arguments: [
        ("https://monica.test/", "https://monica.test"),
        ("https://monica.test///", "https://monica.test"),
        ("https://monica.test", "https://monica.test"),
        ("", ""),
    ])
    func `an address loses every trailing slash`(address: String, trimmed: String) {
        #expect(address.trimmingSuffix("/") == trimmed)
    }

    @Test func `an empty suffix leaves the text as it is`() {
        #expect("abc".trimmingSuffix("") == "abc")
    }
}
