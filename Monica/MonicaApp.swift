import SwiftUI

@main
struct MonicaApp: App {
    @State private var welcome = WelcomeViewModel(instanceRepository: InstanceRepository(defaults: Self.defaults()))

    var body: some Scene {
        WindowGroup {
            WelcomeRoute(viewModel: welcome)
        }
    }

    /// Where the app keeps its preferences. UI tests pass their own store in the
    /// `MONICA_DEFAULTS_SUITE` environment variable, so that each test starts from a fresh app and
    /// can still relaunch it to check what was kept.
    private static func defaults() -> UserDefaults {
        #if DEBUG
            if let suite = ProcessInfo.processInfo.environment["MONICA_DEFAULTS_SUITE"],
               let defaults = UserDefaults(suiteName: suite)
            {
                return defaults
            }
        #endif
        return .standard
    }
}
