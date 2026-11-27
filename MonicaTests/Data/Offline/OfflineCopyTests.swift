import Foundation
@testable import Monica
import SwiftData
import Testing

/// A folder of its own for each test, removed by nobody: the system cleans the temporary folder.
func temporaryCopyFolder() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "OfflineCopy-\(UUID().uuidString)", directoryHint: .isDirectory)
}

@MainActor
struct OfflineCopyTests {
    private let folder = temporaryCopyFolder()
    private let owner = UUID()
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func copy(protectedData: Bool = true) -> OfflineCopy {
        OfflineCopy(directory: folder, isProtectedDataAvailable: { protectedData })
    }

    private var folderExists: Bool {
        FileManager.default.fileExists(atPath: folder.path())
    }

    private func vaultCount(in copy: OfflineCopy) throws -> Int {
        let context = try #require(copy.context)
        return try context.fetchCount(FetchDescriptor<CachedVault>())
    }

    private func addVault(to copy: OfflineCopy) throws {
        let context = try #require(copy.context)
        context.insert(CachedVault(
            serverID: "v1",
            syncedAt: start,
            position: 0,
            name: "Personal",
            details: nil,
            colour: "#3f5fd0",
            isDefault: true,
            contactCount: 0
        ))
        copy.save()
    }

    // MARK: Opening

    @Test func `opening makes a folder kept out of backups, owned by the session`() throws {
        let copy = copy()

        copy.open(owner: owner, now: start)

        #expect(folderExists)
        let values = try URL(filePath: folder.path(), directoryHint: .isDirectory).resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
        let info = try #require(try copy.context?.fetch(FetchDescriptor<CopyInfo>()).first)
        #expect(info.owner == owner)
        #expect(info.lastContactAt == start)
    }

    @Test func `opening again for the same session keeps what it holds`() throws {
        let first = copy()
        first.open(owner: owner, now: start)
        try addVault(to: first)

        let relaunched = copy()
        relaunched.open(owner: owner, now: start.addingTimeInterval(60))

        #expect(try vaultCount(in: relaunched) == 1)
    }

    @Test func `opening for another session erases what the previous one kept`() throws {
        let first = copy()
        first.open(owner: owner, now: start)
        try addVault(to: first)

        let other = copy()
        let newOwner = UUID()
        other.open(owner: newOwner, now: start)

        #expect(try vaultCount(in: other) == 0)
        #expect(try other.context?.fetch(FetchDescriptor<CopyInfo>()).map(\.owner) == [newOwner])
    }

    @Test func `a store that cannot be read is replaced by an empty one`() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not a database".utf8).write(to: folder.appending(path: OfflineCopy.storeName))
        let copy = copy()

        copy.open(owner: owner, now: start)

        #expect(try vaultCount(in: copy) == 0)
        #expect(try copy.context?.fetch(FetchDescriptor<CopyInfo>()).first?.owner == owner)
    }

    @Test func `before the first unlock nothing is read nor erased`() throws {
        let first = copy()
        first.open(owner: owner, now: start)
        try addVault(to: first)

        let locked = copy(protectedData: false)
        locked.open(owner: UUID(), now: start)

        #expect(locked.context == nil)
        #expect(folderExists)
    }

    // MARK: Expiry

    @Test(arguments: [30 * 24 * 60 * 60 - 60.0, 60])
    func `a copy that reached the instance within 30 days is kept`(silence: TimeInterval) throws {
        let first = copy()
        first.open(owner: owner, now: start)
        try addVault(to: first)

        let relaunched = copy()
        relaunched.open(owner: owner, now: start.addingTimeInterval(silence))

        #expect(try vaultCount(in: relaunched) == 1)
    }

    @Test(arguments: [30 * 24 * 60 * 60 + 60.0, -60])
    func `a copy silent for more than 30 days, or from the future, is erased`(silence: TimeInterval) throws {
        let first = copy()
        first.open(owner: owner, now: start)
        try addVault(to: first)

        let relaunched = copy()
        relaunched.open(owner: owner, now: start.addingTimeInterval(silence))

        #expect(try vaultCount(in: relaunched) == 0)
        #expect(try relaunched.context?.fetch(FetchDescriptor<CopyInfo>()).first?.lastContactAt == start.addingTimeInterval(silence))
    }

    @Test func `a contact is saved at most once an hour`() throws {
        let copy = copy()
        copy.open(owner: owner, now: start)

        copy.recordContact(at: start.addingTimeInterval(30 * 60))
        #expect(try copy.context?.fetch(FetchDescriptor<CopyInfo>()).first?.lastContactAt == start)

        copy.recordContact(at: start.addingTimeInterval(61 * 60))
        #expect(try copy.context?.fetch(FetchDescriptor<CopyInfo>()).first?.lastContactAt == start.addingTimeInterval(61 * 60))
    }

    @Test func `a contact recorded with no copy open does nothing`() {
        let copy = copy()

        copy.recordContact(at: start)

        #expect(!folderExists)
    }

    // MARK: Erasing

    @Test func `erasing removes every file`() throws {
        let copy = copy()
        copy.open(owner: owner, now: start)
        try addVault(to: copy)

        copy.erase()

        #expect(!folderExists)
        #expect(copy.context == nil)
    }

    @Test func `erasing with nothing kept does nothing`() {
        let copy = copy()

        copy.erase()

        #expect(!folderExists)
    }

    @Test func `erasing empties every kind of data the copy holds`() throws {
        let copy = copy()
        copy.open(owner: owner, now: start)
        let context = try #require(copy.context)
        try addVault(to: copy)
        context.insert(Freshness(kind: "vaults", updatedAt: start))
        copy.save()

        copy.erase()
        copy.open(owner: owner, now: start)

        let reopened = try #require(copy.context)
        #expect(OfflineSchemaV1.models.count == 3)
        #expect(try reopened.fetchCount(FetchDescriptor<CachedVault>()) == 0)
        #expect(try reopened.fetchCount(FetchDescriptor<Freshness>()) == 0)
        #expect(try reopened.fetch(FetchDescriptor<CopyInfo>()).map(\.lastContactAt) == [start])
    }
}
