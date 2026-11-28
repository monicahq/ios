import Foundation
import SwiftData

/// The copy of what the instance answered, kept on the phone so screens show it at once and stay
/// readable offline (constitution, principle VIII). See
/// `specs/004-offline-reading/contracts/offline-copy.md`.
///
/// It belongs to one session: `SessionManager` opens it when a session starts or is restored, and
/// erases it whenever a session ends. Repositories only read and write through `context`, and only
/// what the instance answered.
///
/// The store lives in a folder of its own, protected by Data Protection until the phone's first
/// unlock after a restart and kept out of backups. Erasing deletes the folder, so every kind of
/// data kept goes at once. Nothing it holds is ever logged.
@MainActor
final class OfflineCopy {
    static let storeName = "OfflineCopy.store"
    /// Without any answer from the instance for this long, the copy is erased at the next opening.
    static let maximumSilence: TimeInterval = 30 * 24 * 60 * 60
    /// A contact is saved at most this often, to avoid a disk write for every request.
    static let contactInterval: TimeInterval = 60 * 60

    /// Where repositories read and write the copy; nil when there is none right now (signed out,
    /// before the first unlock, or the store could not be opened).
    private(set) var context: ModelContext?

    private let directory: URL
    private let isProtectedDataAvailable: () -> Bool
    private var container: ModelContainer?

    init(directory: URL, isProtectedDataAvailable: @escaping () -> Bool) {
        self.directory = directory
        self.isProtectedDataAvailable = isProtectedDataAvailable
    }

    /// Opens the copy of `owner`'s session. What the store holds is erased first when it belongs
    /// to another session, cannot be read, has not reached the instance for 30 days, or comes from
    /// the future (a clock moved back). Before the first unlock, nothing is read nor erased.
    func open(owner: UUID, now: Date) {
        close()
        guard isProtectedDataAvailable(), let context = makeContext() ?? eraseAndMakeContext() else { return }
        if let info = try? context.fetch(FetchDescriptor<CopyInfo>()).first {
            let silence = now.timeIntervalSince(info.lastContactAt)
            if info.owner == owner, silence >= 0, silence <= Self.maximumSilence {
                self.context = context
                return
            }
        }
        guard let fresh = eraseAndMakeContext() else { return }
        fresh.insert(CopyInfo(owner: owner, lastContactAt: now))
        try? fresh.save()
        self.context = fresh
    }

    /// Deletes everything the copy holds. Called by `SessionManager` before it says the session
    /// ended. A deletion that fails is finished by the next opening, which finds another owner.
    func erase() {
        close()
        try? FileManager.default.removeItem(at: directory)
    }

    /// At a launch with no session, erases what a session left. Before the first unlock, nothing is
    /// erased: the Keychain cannot be read either, so the session may still exist.
    func sweep() {
        guard isProtectedDataAvailable() else { return }
        erase()
    }

    /// Notes that the instance answered, for the 30-day limit.
    func recordContact(at now: Date) {
        guard let context, let info = try? context.fetch(FetchDescriptor<CopyInfo>()).first,
              now.timeIntervalSince(info.lastContactAt) >= Self.contactInterval
        else { return }
        info.lastContactAt = now
        save()
    }

    /// Saves what a repository changed. A failure (storage full) is ignored: the app keeps working
    /// online, and the copy is written again at the next answer.
    func save() {
        try? context?.save()
    }

    private func close() {
        context = nil
        container = nil
    }

    private func eraseAndMakeContext() -> ModelContext? {
        erase()
        return makeContext()
    }

    private func makeContext() -> ModelContext? {
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
            var folder = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            let configuration = ModelConfiguration(
                schema: Schema(versionedSchema: OfflineSchemaV1.self),
                url: directory.appending(path: Self.storeName)
            )
            let container = try ModelContainer(
                for: Schema(versionedSchema: OfflineSchemaV1.self),
                migrationPlan: OfflineMigrationPlan.self,
                configurations: configuration
            )
            self.container = container
            return container.mainContext
        } catch {
            return nil
        }
    }
}
