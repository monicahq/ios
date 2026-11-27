import Foundation
import SwiftData

/// Every model of the offline copy, in one store: erasing the store erases them all, so no feature
/// erases its own (constitution, principle VIII). A feature that reads offline adds its model here;
/// once a store has shipped, it adds a new schema version and a migration stage instead.
/// See `specs/004-offline-reading/data-model.md`.
enum OfflineSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [CopyInfo.self, Freshness.self, CachedVault.self]
    }

    /// The store's one row: which session it belongs to, and when the instance last answered.
    @Model
    final class CopyInfo {
        var owner: UUID
        /// Saved at most once an hour; more than 30 days old, the copy is erased.
        var lastContactAt: Date

        init(owner: UUID, lastContactAt: Date) {
            self.owner = owner
            self.lastContactAt = lastContactAt
        }
    }

    /// When the instance last answered a whole list. A list without this row has no copy.
    @Model
    final class Freshness {
        /// `vaults` today; later `contacts:<vault id>` and so on.
        @Attribute(.unique) var kind: String
        var updatedAt: Date

        init(kind: String, updatedAt: Date) {
            self.kind = kind
            self.updatedAt = updatedAt
        }
    }

    /// A vault as the instance last answered it, with the five sync fields every record carries.
    @Model
    final class CachedVault {
        /// Its identity on the phone, which a record created offline will have before the instance
        /// knows it.
        @Attribute(.unique) var localID: UUID
        /// The instance's id; nil only for a record created offline and not sent yet. Unique by the
        /// refresh rule rather than by the store, which would treat two nils as a clash.
        var serverID: String?
        var syncState: SyncState
        /// The instance's `updated_at`, to notice later that the instance changed a record edited
        /// offline.
        var serverUpdatedAt: Date?
        /// When this row last came from the instance.
        var syncedAt: Date
        /// Its index in the last list answered.
        var position: Int
        var name: String
        /// The vault's description (`description` is taken by `CustomStringConvertible`).
        var details: String?
        /// As the API sends it, so a colour the app does not know survives.
        var colour: String
        var isDefault: Bool
        var contactCount: Int

        init(
            serverID: String,
            serverUpdatedAt: Date? = nil,
            syncedAt: Date,
            position: Int,
            name: String,
            details: String?,
            colour: String,
            isDefault: Bool,
            contactCount: Int
        ) {
            localID = UUID()
            self.serverID = serverID
            syncState = .synced
            self.serverUpdatedAt = serverUpdatedAt
            self.syncedAt = syncedAt
            self.position = position
            self.name = name
            self.details = details
            self.colour = colour
            self.isDefault = isDefault
            self.contactCount = contactCount
        }
    }
}

typealias CopyInfo = OfflineSchemaV1.CopyInfo
typealias Freshness = OfflineSchemaV1.Freshness
typealias CachedVault = OfflineSchemaV1.CachedVault

/// How a store of an older schema becomes the current one. Nothing to migrate yet.
enum OfflineMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [OfflineSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
