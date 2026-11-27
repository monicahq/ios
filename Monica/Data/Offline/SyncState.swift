/// Whether a record of the offline copy matches the instance, or holds a change made on the phone
/// that the instance has not received yet.
///
/// Today the app only writes `.synced`: the copy is read only (constitution, principle VIII). The
/// other cases exist so that the refresh rule (`reconcile`) is already tested against them, and so
/// that the stored values never change when offline writing arrives:
///
/// - new on the phone → `.pendingCreate` → sent → `.synced` (with its `serverID`)
/// - `.synced` → edited offline → `.pendingUpdate` → sent → `.synced`
/// - `.synced` → deleted offline → `.pendingDelete` → sent → removed
///
/// See `specs/004-offline-reading/data-model.md`.
enum SyncState: String, Codable, Sendable {
    case synced
    case pendingCreate
    case pendingUpdate
    case pendingDelete
}
