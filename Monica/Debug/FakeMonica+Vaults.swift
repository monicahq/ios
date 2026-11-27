#if DEBUG
    import Foundation

    /// The vaults of the fake Monica: what `GET` and `POST /api/v1/vaults` and
    /// `GET /api/v1/vaults/{id}` answer, from the vaults in its settings.
    extension FakeMonica {
        /// An unreachable instance, or a vault route, answered here; nil for the other routes.
        func vaultsOrUnreachable(_ request: Request, settings: Settings) -> Answer? {
            if settings.unreachable {
                return .failure(.cannotConnectToHost)
            }
            guard let range = request.url.path().range(of: "/api/v1/vaults") else { return nil }
            return vaults(request, route: String(request.url.path()[range.upperBound...]))
        }

        /// The vaults of the UI tests' `withVaults` account: one default, and the three ways of
        /// counting contacts.
        static let threeVaults = [
            Vault(id: "personal", name: "Personal", description: "Friends and the people I meet.", isDefault: true, contactCount: 25),
            Vault(id: "family", name: "Family", colour: "#4f8a49", contactCount: 1),
            Vault(id: "work", name: "Work", description: "Dunder Mifflin, Scranton branch.", colour: "#9a6a24"),
        ]

        /// `GET /api/v1/vaults`, `GET /api/v1/vaults/{id}` and `POST /api/v1/vaults`, as
        /// `resources/docs/api/05-vaults.php` describes them. `route` is what follows `/api/v1/vaults`.
        func vaults(_ request: Request, route: String) -> Answer {
            guard request.headers["Authorization"]?.hasPrefix("Bearer ") == true else {
                return .json(401, #"{"message":"Unauthenticated."}"#)
            }
            return state.withLock { state in
                switch (request.method, route) {
                case ("GET", ""):
                    state.vaultListCount += 1
                    if let limit = state.settings.vaultListFailsAfter, state.vaultListCount > limit {
                        return .failure(.notConnectedToInternet)
                    }
                    let answer = Self.vaultPage(state.settings.vaults, query: request.url)
                    let delay = state.settings.vaultListDelay
                    return delay > 0 ? .delayed(delay, answer) : answer
                case ("POST", ""):
                    return Self.create(request.body, in: &state.settings)
                case ("GET", _):
                    let id = String(route.dropFirst())
                    guard !state.settings.goneVaultIDs.contains(id),
                          let vault = state.settings.vaults.first(where: { $0.id == id })
                    else { return .json(404, #"{"message":"Not found."}"#) }
                    return .json(200, #"{"data":\#(Self.json(vault, position: 1))}"#)
                default:
                    return .json(405, #"{"message":"Method not allowed."}"#)
                }
            }
        }

        private static func vaultPage(_ vaults: [Vault], query url: URL) -> Answer {
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            func number(_ name: String, _ fallback: Int) -> Int {
                items.first { $0.name == name }?.value.flatMap(Int.init) ?? fallback
            }
            let page = max(number("page", 1), 1)
            let perPage = min(max(number("per_page", 25), 1), 100)
            let start = min((page - 1) * perPage, vaults.count)
            let slice = vaults[start ..< min(start + perPage, vaults.count)]
            let data = slice.enumerated().map { json($1, position: start + $0 + 1) }.joined(separator: ",")
            return .json(200, #"{"data":[\#(data)],"meta":{"page":\#(page),"per_page":\#(perPage),"total":\#(vaults.count)}}"#)
        }

        private static func create(_ body: Data, in settings: inout Settings) -> Answer {
            let fields = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
            let name = (fields["name"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
            if name.isEmpty {
                return refusal("The name field is required.")
            }
            if let limit = settings.vaultLimit, settings.vaults.count >= limit {
                return refusal("The free plan holds \(limit) vault, and this account already has it. Full access lifts the ceiling.")
            }
            let makeDefault = settings.vaults.isEmpty || fields["is_default"] as? Bool == true
            if makeDefault {
                for index in settings.vaults.indices {
                    settings.vaults[index].isDefault = false
                }
            }
            let vault = Vault(
                id: UUID().uuidString.lowercased(),
                name: name,
                description: fields["description"] as? String,
                colour: fields["colour"] as? String ?? "#3f5fd0",
                isDefault: makeDefault
            )
            settings.vaults.append(vault)
            return .json(201, #"{"data":\#(json(vault, position: settings.vaults.count))}"#)
        }

        private static func refusal(_ message: String) -> Answer {
            let text = jsonString(message)
            return .json(422, #"{"message":\#(text),"errors":{"name":[\#(text)]}}"#)
        }

        private static func json(_ vault: Vault, position: Int) -> String {
            let description = vault.description.map(jsonString) ?? "null"
            return """
            {"type":"vault","id":"\(vault.id)","attributes":{"slug":"\(vault.id)","name":\(jsonString(vault.name)),\
            "description":\(description),"colour":"\(vault.colour)","position":\(position),\
            "is_default":\(vault.isDefault),"contact_count":\(vault.contactCount),"shows_people":true,\
            "shows_things":true,"shows_knowledge":true,"created_at":1756252800,"updated_at":1756252800},\
            "links":{"self":"https://monica.test/api/v1/vaults/\(vault.id)","web":"https://monica.test/vaults/\(vault.id)"}}
            """
        }

        private static func jsonString(_ text: String) -> String {
            (try? JSONSerialization.data(withJSONObject: [text], options: [.fragmentsAllowed]))
                .flatMap { String(data: $0, encoding: .utf8) }
                .map { String($0.dropFirst().dropLast()) } ?? "\"\""
        }
    }
#endif
