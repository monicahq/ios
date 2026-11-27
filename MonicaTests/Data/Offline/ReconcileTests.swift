@testable import Monica
import Testing

struct ReconcileTests {
    private typealias Row = (serverID: String?, state: SyncState)

    @Test func `updates the records the answer still holds, inserts the new ones, deletes the others`() {
        let existing: [Row] = [("a", .synced), ("b", .synced), ("c", .synced)]

        let changes = reconcile(existing: existing, incoming: ["c", "a", "d"])

        #expect(changes.update == ["a", "c"])
        #expect(changes.insert == ["d"])
        #expect(changes.delete == ["b"])
    }

    @Test func `keeps the order of the new records as the answer gives it`() {
        let changes = reconcile(existing: [], incoming: ["z", "x", "y"])

        #expect(changes.insert == ["z", "x", "y"])
    }

    @Test(arguments: [SyncState.pendingCreate, .pendingUpdate, .pendingDelete])
    func `never touches a record with a change waiting`(state: SyncState) {
        let existing: [Row] = [("a", state), ("b", state)]

        let changes = reconcile(existing: existing, incoming: ["a"])

        #expect(changes.update.isEmpty)
        #expect(changes.insert.isEmpty)
        #expect(changes.delete.isEmpty)
    }

    @Test func `keeps a record created on the phone that the instance does not know yet`() {
        let existing: [Row] = [(nil, .pendingCreate), ("a", .synced)]

        let changes = reconcile(existing: existing, incoming: [])

        #expect(changes.delete == ["a"])
        #expect(changes.update.isEmpty)
    }

    @Test func `an empty answer deletes only the records matching the instance`() {
        let existing: [Row] = [("a", .synced), ("b", .pendingUpdate)]

        let changes = reconcile(existing: existing, incoming: [])

        #expect(changes.delete == ["a"])
    }

    @Test func `an id answered twice is inserted once`() {
        let changes = reconcile(existing: [], incoming: ["a", "a"])

        #expect(changes.insert == ["a"])
    }
}
