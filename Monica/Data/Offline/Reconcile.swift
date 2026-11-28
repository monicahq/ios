/// What an answer from the instance changes in the offline copy of a list.
struct SyncChanges: Equatable {
    /// Records to refresh with the instance's answer, by the instance's id.
    var update: Set<String> = []
    /// Records the instance answered that the copy does not hold yet, in the answer's order.
    var insert: [String] = []
    /// Records the instance no longer answers.
    var delete: Set<String> = []
}

/// The refresh rule of the offline copy: an answer from the instance only inserts, replaces or
/// removes records that match the instance (`.synced`). A record holding a change waiting to be sent
/// is never overwritten nor removed by a refresh, so offline writing can be added later without
/// changing this rule.
///
/// `existing` is every record of the list in the copy; `incoming` is every id the instance answered.
func reconcile(existing: [(serverID: String?, state: SyncState)], incoming: [String]) -> SyncChanges {
    let known = Set(existing.compactMap(\.serverID))
    let synced = Set(existing.filter { $0.state == .synced }.compactMap(\.serverID))
    var changes = SyncChanges()
    var seen: Set<String> = []
    for id in incoming where seen.insert(id).inserted {
        if synced.contains(id) {
            changes.update.insert(id)
        } else if !known.contains(id) {
            changes.insert.append(id)
        }
    }
    changes.delete = synced.subtracting(seen)
    return changes
}
