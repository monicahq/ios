import Foundation

/// The single source of truth for vaults: every screen asks it, and it asks the instance. Nothing is
/// kept on the phone. See `specs/003-vaults-list/contracts/monica-api.md`.
@MainActor
final class VaultRepository {
    /// The most the API answers in one page.
    static let pageSize = 100

    private let sessionManager: SessionManager

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
    }

    /// Every vault of the account, in the order the person arranged them, whatever their number.
    func vaults() async throws(ApiError) -> [Vault] {
        var vaults: [Vault] = []
        var page = 1
        while true {
            let answer: VaultPage = try await get("/api/v1/vaults?page=\(page)&per_page=\(Self.pageSize)")
            vaults += answer.data.map(\.vault)
            // An empty page also ends it, in case vaults were deleted while loading.
            if answer.data.isEmpty || vaults.count >= answer.meta.total {
                return vaults
            }
            page += 1
        }
    }

    func vault(id: String) async throws(ApiError) -> Vault {
        let path = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let answer: OneVault = try await get("/api/v1/vaults/\(path)")
        return answer.data.vault
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
