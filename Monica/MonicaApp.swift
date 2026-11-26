import SwiftUI

@main
struct MonicaApp: App {
    var body: some Scene {
        WindowGroup {
            // Nothing is wired yet: signing up, logging in and choosing the instance come in the
            // next features.
            WelcomeScreen(
                instanceHost: instanceHost(defaultInstanceURL),
                onSignUp: {},
                onLogIn: {},
                onInstanceSettings: {}
            )
        }
    }
}
