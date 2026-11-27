import Foundation
@testable import Monica
import Testing

/// Runs against the simulator's real Keychain, each test on a service of its own.
struct KeychainSecretStoreTests {
    private struct Value: Codable, Equatable {
        var text: String
    }

    private let store = KeychainSecretStore(service: "com.monicahq.ios.tests.\(UUID().uuidString)")

    @Test func `reads back what it wrote`() throws {
        try store.write(Value(text: "first"), for: .session)

        #expect(store.read(.session, as: Value.self) == Value(text: "first"))
        store.delete(.session)
    }

    @Test func `a second write replaces the value whole`() throws {
        try store.write(Value(text: "first"), for: .session)
        try store.write(Value(text: "second"), for: .session)

        #expect(store.read(.session, as: Value.self) == Value(text: "second"))
        store.delete(.session)
    }

    @Test func `keys are kept apart`() throws {
        try store.write(Value(text: "session"), for: .session)

        #expect(store.read(.pendingSignIn, as: Value.self) == nil)
        store.delete(.session)
    }

    @Test func `nothing is read after a delete`() throws {
        try store.write(Value(text: "first"), for: .session)

        store.delete(.session)

        #expect(store.read(.session, as: Value.self) == nil)
    }

    @Test func `a value that no longer decodes is deleted`() throws {
        try store.write("not a value", for: .session)

        #expect(store.read(.session, as: Value.self) == nil)
        #expect(store.read(.session, as: String.self) == nil)
    }

    @Test func `a fresh install starts without the secrets an earlier install left`() throws {
        let defaults = temporaryDefaults()
        try store.write(Value(text: "left behind"), for: .session)
        try store.write(Value(text: "left behind"), for: .pendingRevocation)

        store.wipeIfFreshInstall(defaults: defaults)

        #expect(store.read(.session, as: Value.self) == nil)
        #expect(store.read(.pendingRevocation, as: Value.self) == nil)
    }

    @Test func `a later launch keeps the secrets`() throws {
        let defaults = temporaryDefaults()
        store.wipeIfFreshInstall(defaults: defaults)
        try store.write(Value(text: "kept"), for: .session)

        store.wipeIfFreshInstall(defaults: defaults)

        #expect(store.read(.session, as: Value.self) == Value(text: "kept"))
        store.delete(.session)
    }
}
