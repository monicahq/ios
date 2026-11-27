import Foundation
@testable import Monica
import Testing

struct VaultTests {
    @Test func `decodes what the list shows and ignores the rest`() throws {
        let json = Data("""
        {"type":"vault","id":"9d4f","attributes":{"slug":"dunder-mifflin","name":"Dunder Mifflin",\
        "description":"Everybody at the Scranton branch.","colour":"#4f8a49","position":1,"is_default":true,\
        "contact_count":12,"shows_people":true,"created_at":1756252800},"links":{"self":"x","web":"y"}}
        """.utf8)

        let vault = try JSONDecoder().decode(VaultResource.self, from: json).vault

        #expect(vault == Vault(
            id: "9d4f",
            name: "Dunder Mifflin",
            description: "Everybody at the Scranton branch.",
            colour: .green,
            isDefault: true,
            contactCount: 12
        ))
    }

    @Test func `a missing description decodes as none`() throws {
        let json = Data("""
        {"id":"1","attributes":{"name":"A","description":null,"colour":"#3f5fd0","is_default":false,"contact_count":0}}
        """.utf8)

        let vault = try JSONDecoder().decode(VaultResource.self, from: json).vault

        #expect(vault.description == nil)
        #expect(vault.shownDescription == nil)
    }

    @Test func `a blank description is not shown`() {
        let vault = Vault(id: "1", name: "A", description: "  \n", colour: .blue, isDefault: false, contactCount: 0)

        #expect(vault.shownDescription == nil)
    }

    @Test func `the initial is the first letter of the name`() {
        let vault = Vault(id: "1", name: "élan", description: nil, colour: .blue, isDefault: false, contactCount: 0)

        #expect(vault.initial == "É")
    }

    // MARK: Colours

    @Test func `colours are read whatever their case`() {
        #expect(VaultColour(server: "#9A3F2B") == .rust)
    }

    @Test func `an unknown colour is drawn neutral`() {
        #expect(VaultColour(server: "#123456") == .graphite)
    }

    @Test func `colours come in the order the web offers them`() {
        #expect(VaultColour.allCases == [.blue, .green, .ochre, .rust, .violet, .teal, .rose, .graphite])
        #expect(VaultColour.allCases.map(\.rawValue) == [
            "#3f5fd0", "#4f8a49", "#9a6a24", "#9a3f2b", "#6b4fa8", "#2f7f86", "#a8447a", "#4a4a52",
        ])
    }

    // MARK: Creating

    private func body(_ vault: NewVault) throws -> [String: AnyHashable] {
        try #require(JSONSerialization.jsonObject(with: vault.json()) as? [String: AnyHashable])
    }

    @Test func `a new vault sends its trimmed name, description and colour`() throws {
        let vault = NewVault(name: "  Family ", description: " Everybody I am related to. ", colour: .green, makeDefault: false)

        #expect(try body(vault) == ["name": "Family", "description": "Everybody I am related to.", "colour": "#4f8a49"])
    }

    @Test func `a blank description is not sent`() throws {
        let vault = NewVault(name: "Family", description: "   ", colour: .blue, makeDefault: false)

        #expect(try body(vault) == ["name": "Family", "colour": "#3f5fd0"])
    }

    @Test func `default is sent only when asked, and never a template`() throws {
        let vault = NewVault(name: "Family", description: nil, colour: .blue, makeDefault: true)

        let sent = try body(vault)

        #expect(sent["is_default"] == AnyHashable(true))
        #expect(sent["structure_version_id"] == nil)
    }
}
