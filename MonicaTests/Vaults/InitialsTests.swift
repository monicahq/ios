import Foundation
@testable import Monica
import Testing

struct InitialsTests {
    private let english = Locale(identifier: "en")

    @Test(arguments: [
        ("Personal", "P"),
        ("  work", "W"),
        ("élan", "É"),
        ("🐼 Pandas", "🐼"),
        ("", ""),
        ("   ", ""),
    ])
    func `the vault initial is the first letter a person sees`(name: String, initial: String) {
        #expect(vaultInitial(name, locale: english) == initial)
    }

    @Test(arguments: [
        ("Michael Scott", "MS"),
        ("Jean-Pierre Martin", "JM"),
        ("dwight k. schrute", "DK"),
        ("Pam", "P"),
        ("  Ryan   Howard  ", "RH"),
        ("1st Floor Kevin", "FK"),
        ("Élodie Œuvre", "ÉŒ"),
    ])
    func `the person initials are the first letters of two words`(name: String, initials: String) {
        #expect(personInitials(name, locale: english) == initials)
    }

    @Test(arguments: ["", "   ", "123 456", "— !"])
    func `a name without letters has no initials`(name: String) {
        #expect(personInitials(name, locale: english) == nil)
    }
}
