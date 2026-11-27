import Foundation
@testable import Monica
import Synchronization
import Testing

/// The Keychain, in memory: what `SessionManager` stores, without touching the real Keychain.
final class FakeSecretStore: SecretStore {
    private let values = Mutex<[SecretKey: Data]>([:])
    /// Makes every write fail, like a Keychain that refuses.
    let failsWrites: Bool

    init(failsWrites: Bool = false) {
        self.failsWrites = failsWrites
    }

    func read<Value: Decodable>(_ key: SecretKey, as type: Value.Type) -> Value? {
        values.withLock { $0[key] }.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    func write(_ value: some Encodable, for key: SecretKey) throws {
        if failsWrites {
            throw Refused()
        }
        let data = try JSONEncoder().encode(value)
        values.withLock { $0[key] = data }
    }

    func delete(_ key: SecretKey) {
        _ = values.withLock { $0.removeValue(forKey: key) }
    }

    func contains(_ key: SecretKey) -> Bool {
        values.withLock { $0[key] != nil }
    }
}

private struct Refused: Error {}

/// A clock the test moves by hand.
final class FakeClock: Sendable {
    private let current = Mutex(Date(timeIntervalSince1970: 1_800_000_000))

    var now: Date {
        current.withLock { $0 }
    }

    func advance(by interval: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(interval) }
    }
}

/// The app's parts wired to a fake Monica, a fake Keychain and a fake clock.
@MainActor
struct Harness {
    let monica: FakeMonica
    let store: FakeSecretStore
    let clock: FakeClock
    let repository: InstanceRepository
    let checker: InstanceChecker
    let sessionManager: SessionManager

    init(
        monica: FakeMonica = FakeMonica(),
        store: FakeSecretStore = FakeSecretStore(),
        clock: FakeClock = FakeClock(),
        appVersion: String = "1.0.0"
    ) {
        self.monica = monica
        self.store = store
        self.clock = clock
        repository = InstanceRepository(defaults: temporaryDefaults())
        repository.setURL(monica.base)
        checker = InstanceChecker(configuration: FakeMonica.configuration, appVersion: appVersion, allowsHTTP: false)
        sessionManager = SessionManager(
            store: store,
            configuration: FakeMonica.configuration,
            deviceName: "iPhone · iOS 26.1",
            now: { [clock] in clock.now }
        )
    }

    /// Another session manager on the same Keychain: the app after a relaunch.
    func relaunched() -> SessionManager {
        SessionManager(
            store: store,
            configuration: FakeMonica.configuration,
            deviceName: "iPhone · iOS 26.1",
            now: { [clock] in clock.now }
        )
    }

    func description() async throws -> InstanceDescription {
        try await checker.check(base: monica.base)
    }

    /// The address the instance sends the person back to after they allowed access.
    static func callback(for page: URL, query: String = "code=the-code") throws -> URL {
        let state = URLComponents(url: page, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "state" }?.value ?? ""
        return try url("\(signInReturnAddress)?\(query)&state=\(state)")
    }

    /// Signs in through the whole flow, as a person allowing access would.
    func signIn(isSignUp: Bool = false) async throws {
        let page = try await sessionManager.startSignIn(description(), isSignUp: isSignUp)
        try await sessionManager.complete(callback: Self.callback(for: page), currentInstance: monica.base)
    }
}

/// A URL from a literal, failing the test rather than crashing when it is not one.
func url(_ string: String) throws -> URL {
    try #require(URL(string: string))
}
