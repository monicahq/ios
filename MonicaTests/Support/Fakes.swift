import Foundation
@testable import Monica
import Synchronization
import Testing

/// The Keychain, in memory: what `SessionManager` stores, without touching the real Keychain.
final class FakeSecretStore: SecretStore {
    private let values = Mutex<[SecretKey: Data]>([:])
    /// The keys whose writes fail, like a Keychain that refuses.
    let refusedKeys: Set<SecretKey>

    /// `failsWrites` refuses every key; `refusing` only the keys it names.
    init(failsWrites: Bool = false, refusing: Set<SecretKey> = []) {
        refusedKeys = failsWrites ? Set(SecretKey.allCases) : refusing
    }

    func read<Value: Decodable>(_ key: SecretKey, as type: Value.Type) -> Value? {
        values.withLock { $0[key] }.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    func write(_ value: some Encodable, for key: SecretKey) throws {
        if refusedKeys.contains(key) {
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

/// Whether the phone has been unlocked since its restart, set by the test.
final class ProtectedData: Sendable {
    private let available = Mutex(true)

    var isAvailable: Bool {
        get { available.withLock { $0 } }
        set { available.withLock { $0 = newValue } }
    }
}

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
    let vaultRepository: VaultRepository
    /// The folder of the offline copy, of its own for each test.
    let copyFolder = temporaryCopyFolder()
    /// What `UIApplication.isProtectedDataAvailable` says for the copies this harness makes.
    let protectedData = ProtectedData()
    let offlineCopy: OfflineCopy

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
        offlineCopy = OfflineCopy(directory: copyFolder, isProtectedDataAvailable: { [protectedData] in protectedData.isAvailable })
        sessionManager = SessionManager(
            store: store,
            configuration: FakeMonica.configuration,
            deviceName: "iPhone · iOS 26.1",
            offlineCopy: offlineCopy,
            now: { [clock] in clock.now }
        )
        vaultRepository = VaultRepository(sessionManager: sessionManager, offlineCopy: offlineCopy, now: { [clock] in clock.now })
    }

    /// Another session manager on the same Keychain and the same offline copy folder: the app
    /// after a relaunch. Its copy is a new one, as after a relaunch.
    func relaunched(copy: OfflineCopy? = nil) -> SessionManager {
        SessionManager(
            store: store,
            configuration: FakeMonica.configuration,
            deviceName: "iPhone · iOS 26.1",
            offlineCopy: copy ?? relaunchedCopy(),
            now: { [clock] in clock.now }
        )
    }

    /// A new offline copy on this harness's folder, as the app makes at launch.
    func relaunchedCopy() -> OfflineCopy {
        OfflineCopy(directory: copyFolder, isProtectedDataAvailable: { [protectedData] in protectedData.isAvailable })
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
