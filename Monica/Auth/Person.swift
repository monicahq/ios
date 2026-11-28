import Foundation

/// The signed-in person, as `/api/v1/me` describes them.
struct Person: Decodable, Equatable {
    let firstName: String
    let lastName: String
    let email: String
    let nameOrder: String?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case nameOrder = "name_order"
    }

    /// Their name in the order they chose on the web.
    var name: String {
        let parts = nameOrder == "family_first" ? [lastName, firstName] : [firstName, lastName]
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }
}

/// `{ "data": { "attributes": <person> } }`, the answer of `/api/v1/me`.
struct MeResponse: Decodable {
    struct Resource: Decodable {
        let attributes: Person
    }

    let data: Resource
}
