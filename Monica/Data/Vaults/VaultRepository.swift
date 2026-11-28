import Foundation
import SwiftData

/// The single source of truth for vaults: every screen asks it, and it asks the instance. What the
/// instance answers is kept in the offline copy, which screens show at once and while the instance
/// cannot be reached. See `specs/003-vaults-list/contracts/monica-api.md` and
/// `specs/004-offline-reading/contracts/offline-copy.md`.
@MainActor
final class VaultRepository {
    /// The most the API answers in one page.
    static let pageSize = 100
    /// The `Freshness` row of the list.
    private static let listKind = "vaults"

    private let sessionManager: SessionManager
    private let offlineCopy: OfflineCopy
    private let now: () -> Date

    init(sessionManager: SessionManager, offlineCopy: OfflineCopy, now: @escaping () -> Date = Date.init) {
        self.sessionManager = sessionManager
        self.offlineCopy = offlineCopy
        self.now = now
    }

    // MARK: The offline copy

    /// The list as the instance last answered it, or nil when no whole list was kept.
    func cachedVaults() -> Cached<[Vault]>? {
        guard let context = offlineCopy.context,
              let freshness = try? context.fetch(listFreshness()).first,
              let rows = try? context.fetch(FetchDescriptor<CachedVault>(sortBy: [SortDescriptor(\.position)]))
        else { return nil }
        return Cached(value: rows.map(\.vault), updatedAt: freshness.updatedAt)
    }

    /// One vault as the instance last answered it, in the list or on its own.
    func cachedVault(id: String) -> Cached<Vault>? {
        guard let row = row(id: id) else { return nil }
        return Cached(value: row.vault, updatedAt: row.syncedAt)
    }

    /// Makes the copy of the list what the instance just answered, leaving any vault with a change
    /// waiting untouched.
    private func keep(_ vaults: [Vault]) {
        guard let context = offlineCopy.context,
              let rows = try? context.fetch(FetchDescriptor<CachedVault>())
        else { return }
        let changes = reconcile(existing: rows.map { ($0.serverID, $0.syncState) }, incoming: vaults.map(\.id))
        let rowsByID = Dictionary(rows.compactMap { row in row.serverID.map { ($0, row) } }, uniquingKeysWith: { first, _ in first })
        let date = now()
        // A vault answered twice (on the edge of two pages) is kept once, at its first place.
        var seen: Set<String> = []
        for (position, vault) in vaults.enumerated() where seen.insert(vault.id).inserted {
            if changes.update.contains(vault.id), let row = rowsByID[vault.id] {
                row.refresh(with: vault, position: position, at: date)
            } else if changes.insert.contains(vault.id) {
                context.insert(CachedVault(vault, position: position, at: date))
            }
        }
        for id in changes.delete {
            if let row = rowsByID[id] {
                context.delete(row)
            }
        }
        if let freshness = try? context.fetch(listFreshness()).first {
            freshness.updatedAt = date
        } else {
            context.insert(Freshness(kind: Self.listKind, updatedAt: date))
        }
        offlineCopy.save()
    }

    /// Makes the copy of one vault what the instance just answered: nil means it no longer exists.
    private func keep(_ vault: Vault?, id: String) {
        guard let context = offlineCopy.context else { return }
        let row = row(id: id)
        guard row?.syncState ?? .synced == .synced else { return }
        if let vault {
            if let row {
                row.refresh(with: vault, position: row.position, at: now())
            } else {
                context.insert(CachedVault(vault, position: Int.max, at: now()))
            }
        } else if let row {
            context.delete(row)
        }
        offlineCopy.save()
    }

    private func row(id: String) -> CachedVault? {
        var descriptor = FetchDescriptor<CachedVault>(predicate: #Predicate { $0.serverID == id })
        descriptor.fetchLimit = 1
        return try? offlineCopy.context?.fetch(descriptor).first
    }

    private func listFreshness() -> FetchDescriptor<Freshness> {
        let kind = Self.listKind
        return FetchDescriptor<Freshness>(predicate: #Predicate { $0.kind == kind })
    }

    // MARK: The instance

    /// Every vault of the account, in the order the person arranged them, whatever their number.
    func vaults() async throws(ApiError) -> [Vault] {
        var vaults: [Vault] = []
        var page = 1
        while true {
            let answer: VaultPage = try await get("/api/v1/vaults?page=\(page)&per_page=\(Self.pageSize)")
            vaults += answer.data.map(\.vault)
            // An empty page also ends it, in case vaults were deleted while loading.
            if answer.data.isEmpty || vaults.count >= answer.meta.total {
                keep(vaults)
                return vaults
            }
            page += 1
        }
    }

    func vault(id: String) async throws(ApiError) -> Vault {
        let path = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        do {
            let answer: OneVault = try await get("/api/v1/vaults/\(path)")
            keep(answer.data.vault, id: id)
            return answer.data.vault
        } catch .notFound {
            keep(nil, id: id)
            throw .notFound
        }
    }

    /// Creates a vault and returns it as the instance recorded it.
    func create(_ vault: NewVault) async throws(ApiError) -> Vault {
        let response = try await send("POST", "/api/v1/vaults", json: vault.json())
        let answer: OneVault = try decode(response)
        return answer.data.vault
    }

    private func get<Value: Decodable>(_ path: String) async throws(ApiError) -> Value {
        try await decode(send("GET", path, json: nil))
    }

    private func send(_ method: String, _ path: String, json: Data?) async throws(ApiError) -> MonicaClient.Response {
        do {
            return try await sessionManager.authorized(method, path, json: json)
        } catch {
            throw ApiError(error)
        }
    }

    /// Turns an answer into a value or the error its status stands for.
    private func decode<Value: Decodable>(_ response: MonicaClient.Response) throws(ApiError) -> Value {
        switch response.status {
        case 200 ..< 300:
            guard let value = try? JSONDecoder().decode(Value.self, from: response.data) else {
                throw .failed(.unexpectedAnswer)
            }
            return value
        case 403:
            throw .failed(.notAllowed)
        case 404:
            throw .notFound
        case 422:
            guard let refusal = Refusal(json: response.data) else { throw .failed(.unexpectedAnswer) }
            throw .invalid(refusal)
        default:
            throw .failed(.unexpectedAnswer)
        }
    }
}

private extension CachedVault {
    convenience init(_ vault: Vault, position: Int, at date: Date) {
        self.init(
            serverID: vault.id,
            serverUpdatedAt: vault.updatedAt,
            syncedAt: date,
            position: position,
            name: vault.name,
            details: vault.description,
            colour: vault.colour.rawValue,
            isDefault: vault.isDefault,
            contactCount: vault.contactCount
        )
    }

    func refresh(with vault: Vault, position: Int, at date: Date) {
        serverUpdatedAt = vault.updatedAt
        syncedAt = date
        self.position = position
        name = vault.name
        details = vault.description
        colour = vault.colour.rawValue
        isDefault = vault.isDefault
        contactCount = vault.contactCount
    }

    var vault: Vault {
        Vault(
            id: serverID ?? localID.uuidString,
            name: name,
            description: details,
            colour: VaultColour(server: colour),
            isDefault: isDefault,
            contactCount: contactCount,
            updatedAt: serverUpdatedAt
        )
    }
}
