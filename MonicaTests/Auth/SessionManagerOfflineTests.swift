import Foundation
@testable import Monica
import Observation
import SwiftData
import Synchronization
import Testing

/// The offline copy's life follows the session's: opened for a session, erased whenever it ends,
/// swept at launch (constitution, principle VIII; spec FR-008 to FR-013).
@MainActor
struct SessionManagerOfflineTests {
    private let harness = Harness()

    private var folderExists: Bool {
        FileManager.default.fileExists(atPath: harness.copyFolder.path())
    }

    private func info(_ copy: OfflineCopy) throws -> CopyInfo {
        try #require(try copy.context?.fetch(FetchDescriptor<CopyInfo>()).first)
    }

    /// Something kept in the copy, to tell a kept copy from an emptied one.
    private func keepSomething(in copy: OfflineCopy) throws {
        try #require(copy.context).insert(Freshness(kind: "vaults", updatedAt: harness.clock.now))
        copy.save()
    }

    private func keepsSomething(_ copy: OfflineCopy) throws -> Bool {
        try (copy.context?.fetchCount(FetchDescriptor<Freshness>()) ?? 0) > 0
    }

    /// Runs `action`, and says whether the copy's folder was already gone when the session manager
    /// announced the next change of its state.
    private func folderGoneWhenStateChanges(_ action: () async throws -> Void) async rethrows -> Bool? {
        let gone = Mutex<Bool?>(nil)
        let folder = harness.copyFolder.path()
        withObservationTracking {
            _ = harness.sessionManager.state
        } onChange: {
            gone.withLock { $0 = !FileManager.default.fileExists(atPath: folder) }
        }
        try await action()
        return gone.withLock { $0 }
    }

    // MARK: Signing in

    @Test func `signing in opens a copy owned by the new session`() async throws {
        try await harness.signIn()

        let session = try #require(harness.sessionManager.session)
        #expect(try info(harness.offlineCopy).owner == session.copyOwner)
        #expect(try info(harness.offlineCopy).lastContactAt == harness.clock.now)
    }

    @Test func `signing in erases what another session left`() async throws {
        let leftover = harness.relaunchedCopy()
        leftover.open(owner: UUID(), now: harness.clock.now)
        try keepSomething(in: leftover)

        try await harness.signIn()

        #expect(try !keepsSomething(harness.offlineCopy))
    }

    @Test func `each sign-in makes a new owner, even for the same account`() async throws {
        try await harness.signIn()
        let first = try #require(harness.sessionManager.session?.copyOwner)
        await harness.sessionManager.logOut()

        try await harness.signIn()

        #expect(harness.sessionManager.session?.copyOwner != first)
    }

    // MARK: Every session end erases it first

    @Test(arguments: [false, true])
    func `logging out erases the copy before saying so, reachable or not`(unreachable: Bool) async throws {
        try await harness.signIn()
        try keepSomething(in: harness.offlineCopy)
        harness.monica.settings.unreachable = unreachable

        let gone = await folderGoneWhenStateChanges { await harness.sessionManager.logOut() }

        #expect(gone == true)
        #expect(!folderExists)
        #expect(harness.sessionManager.state == .signedOut(.loggedOut))
    }

    @Test func `switching instance erases the copy before saying so`() async throws {
        try await harness.signIn()

        let gone = await folderGoneWhenStateChanges { await harness.sessionManager.logOut(reason: .instanceChanged) }

        #expect(gone == true)
        #expect(harness.sessionManager.state == .signedOut(.instanceChanged))
    }

    @Test func `a refused renewal erases the copy before saying so`() async throws {
        try await harness.signIn()
        harness.monica.settings.refusesRenewal = true
        harness.clock.advance(by: 3600)

        let gone = await folderGoneWhenStateChanges {
            _ = try? await harness.sessionManager.authorizedGet("/api/v1/me")
        }

        #expect(gone == true)
        #expect(harness.sessionManager.state == .signedOut(.ended))
    }

    @Test func `an expired session erases the copy before saying so`() async throws {
        try await harness.signIn()
        harness.monica.settings.refusesRenewal = true
        harness.clock.advance(by: 31 * 24 * 3600)

        let gone = await folderGoneWhenStateChanges {
            _ = try? await harness.sessionManager.authorizedGet("/api/v1/me")
        }

        #expect(gone == true)
        #expect(harness.sessionManager.state == .signedOut(.expired))
    }

    @Test func `a session the instance ended erases the copy`() async throws {
        try await harness.signIn()
        try keepSomething(in: harness.offlineCopy)
        harness.monica.settings.override = { request in
            request.url.path().hasSuffix("/api/v1/me") ? .json(401, #"{"message":"Unauthenticated."}"#) : nil
        }

        _ = try? await harness.sessionManager.authorizedGet("/api/v1/me")

        #expect(harness.sessionManager.state == .signedOut(.ended))
        #expect(!folderExists)
    }

    // MARK: Sweeping at launch

    @Test func `a launch signed out erases a copy found on disk`() {
        let leftover = harness.relaunchedCopy()
        leftover.open(owner: UUID(), now: harness.clock.now)

        _ = harness.relaunched()

        #expect(!folderExists)
    }

    @Test func `a launch signed in keeps the session's own copy`() async throws {
        try await harness.signIn()
        try keepSomething(in: harness.offlineCopy)
        harness.clock.advance(by: 3600)

        let copy = harness.relaunchedCopy()
        _ = harness.relaunched(copy: copy)

        #expect(try keepsSomething(copy))
    }

    @Test func `a launch finding a copy of another session erases it`() async throws {
        try await harness.signIn()
        try keepSomething(in: harness.offlineCopy)
        var session = try #require(harness.store.read(.session, as: Session.self))
        session.copyOwner = UUID()
        try harness.store.write(session, for: .session)

        let copy = harness.relaunchedCopy()
        _ = harness.relaunched(copy: copy)

        #expect(try !keepsSomething(copy))
        #expect(try info(copy).owner == session.copyOwner)
    }

    @Test(arguments: [31 * 24 * 3600.0, -3600])
    func `a launch 30 days after the last contact, or before it, erases the copy`(shift: TimeInterval) async throws {
        try await harness.signIn()
        try keepSomething(in: harness.offlineCopy)
        harness.clock.advance(by: shift)

        let copy = harness.relaunchedCopy()
        _ = harness.relaunched(copy: copy)

        #expect(try !keepsSomething(copy))
    }

    @Test func `a launch before the first unlock reads and erases nothing`() async throws {
        try await harness.signIn()
        try keepSomething(in: harness.offlineCopy)
        harness.protectedData.isAvailable = false

        let copy = harness.relaunchedCopy()
        _ = harness.relaunched(copy: copy)

        #expect(copy.context == nil)
        #expect(folderExists)
    }

    @Test func `a launch before the first unlock erases nothing, though the Keychain cannot be read`() async throws {
        try await harness.signIn()
        try keepSomething(in: harness.offlineCopy)
        harness.protectedData.isAvailable = false

        // Before the first unlock the Keychain answers nothing either: the app looks signed out.
        _ = SessionManager(
            store: FakeSecretStore(),
            configuration: FakeMonica.configuration,
            deviceName: "iPhone · iOS 26.1",
            offlineCopy: harness.relaunchedCopy(),
            now: { [clock = harness.clock] in clock.now }
        )

        #expect(folderExists)
        harness.protectedData.isAvailable = true
        let copy = harness.relaunchedCopy()
        _ = harness.relaunched(copy: copy)
        #expect(try keepsSomething(copy))
    }

    // MARK: Contact with the instance

    @Test(arguments: [200, 404, 500])
    func `any answer but an unauthenticated one is a contact`(status: Int) async throws {
        try await harness.signIn()
        harness.clock.advance(by: 2 * 3600)
        harness.monica.settings.override = { request in
            request.url.path().hasSuffix("/api/v1/contact-check") ? .json(status, "{}") : nil
        }

        _ = try await harness.sessionManager.authorized("GET", "/api/v1/contact-check")

        #expect(try info(harness.offlineCopy).lastContactAt == harness.clock.now)
    }

    @Test func `an instance that cannot be reached is no contact`() async throws {
        try await harness.signIn()
        let signedInAt = harness.clock.now
        harness.clock.advance(by: 2 * 3600)
        harness.monica.settings.unreachable = true

        _ = try? await harness.sessionManager.authorized("GET", "/api/v1/me")

        #expect(try info(harness.offlineCopy).lastContactAt == signedInAt)
    }
}
