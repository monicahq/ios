import Foundation

/// A compartment of the account, as the list of vaults shows it. Only what the app shows is kept;
/// the slug is not, since it changes when the vault is renamed.
struct Vault: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String?
    let colour: VaultColour
    let isDefault: Bool
    let contactCount: Int
    /// When the instance last changed it, kept with the offline copy to notice later that the
    /// instance changed a vault edited offline.
    var updatedAt: Date?

    /// The letter on the vault's square.
    var initial: String {
        vaultInitial(name)
    }

    /// The description when there is something to show.
    var shownDescription: String? {
        guard let description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return description
    }
}

/// The eight colours a vault can have, in the order the web offers them. The raw value is what the
/// API sends and accepts.
enum VaultColour: String, CaseIterable, Sendable {
    case blue = "#3f5fd0"
    case green = "#4f8a49"
    case ochre = "#9a6a24"
    case rust = "#9a3f2b"
    case violet = "#6b4fa8"
    case teal = "#2f7f86"
    case rose = "#a8447a"
    case graphite = "#4a4a52"

    /// A colour from the API. One the app does not know (added to the server later) is drawn
    /// neutral rather than refused.
    init(server value: String) {
        self = VaultColour(rawValue: value.lowercased()) ?? .graphite
    }
}

/// What the person typed to create a vault.
struct NewVault: Equatable, Sendable {
    var name: String
    var description: String?
    var colour: VaultColour
    var makeDefault: Bool

    /// The body of `POST /api/v1/vaults`: the name trimmed, no blank description, `is_default`
    /// only when asked, and never a template (the account's default one is used).
    func json() -> Data {
        var body: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "colour": colour.rawValue,
        ]
        if let description = description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            body["description"] = description
        }
        if makeDefault {
            body["is_default"] = true
        }
        return (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
    }
}

// MARK: Decoding

/// A vault as the API describes it (a JSON:API resource).
struct VaultResource: Decodable {
    let id: String
    let attributes: VaultAttributes

    var vault: Vault {
        Vault(
            id: id,
            name: attributes.name,
            description: attributes.description,
            colour: VaultColour(server: attributes.colour),
            isDefault: attributes.isDefault,
            contactCount: attributes.contactCount,
            updatedAt: attributes.updatedAt.map { Date(timeIntervalSince1970: $0) }
        )
    }
}

/// The attributes of a vault the app reads; the others are ignored.
struct VaultAttributes: Decodable {
    let name: String
    let description: String?
    let colour: String
    let isDefault: Bool
    let contactCount: Int
    /// Unix seconds.
    let updatedAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case name, description, colour
        case isDefault = "is_default"
        case contactCount = "contact_count"
        case updatedAt = "updated_at"
    }
}

/// One page of `GET /api/v1/vaults`.
struct VaultPage: Decodable {
    struct Meta: Decodable {
        let total: Int
    }

    let data: [VaultResource]
    let meta: Meta
}

/// `{ "data": <vault> }`, the answer for one vault.
struct OneVault: Decodable {
    let data: VaultResource
}
