import SwiftUI

@main
struct MonicaApp: App {
    @State private var sessionManager: SessionManager
    @State private var welcome: WelcomeViewModel
    private let instanceRepository: InstanceRepository
    private let checker: InstanceChecker
    private let browser: Browser?

    init() {
        let defaults = Self.defaults()
        let keychain = KeychainSecretStore(service: Self.keychainService())
        keychain.wipeIfFreshInstall(defaults: defaults)
        var configuration = URLSessionConfiguration.ephemeral
        var browser: Browser?
        #if DEBUG
            if FakeMonica.forUITests() != nil {
                configuration = FakeMonica.configuration
                browser = FakeMonica.uiTestBrowser()
            }
        #endif
        let instanceRepository = InstanceRepository(defaults: defaults)
        let checker = InstanceChecker(configuration: configuration, appVersion: appVersion, allowsHTTP: allowsHTTPInstances)
        let sessionManager = SessionManager(store: keychain, configuration: configuration, deviceName: Self.deviceName())
        self.instanceRepository = instanceRepository
        self.checker = checker
        self.browser = browser
        _sessionManager = State(initialValue: sessionManager)
        _welcome = State(initialValue: WelcomeViewModel(
            instanceRepository: instanceRepository,
            checker: checker,
            sessionManager: sessionManager
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                sessionManager: sessionManager,
                welcome: welcome,
                makeHome: { [sessionManager, instanceRepository, checker] in
                    HomeViewModel(sessionManager: sessionManager, instanceRepository: instanceRepository, checker: checker)
                },
                browser: browser
            )
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

    /// The Keychain service holding the session. Each UI test's store gets its own, as for the
    /// preferences, since the Keychain outlives the app between launches.
    private static func keychainService() -> String {
        #if DEBUG
            if let suite = ProcessInfo.processInfo.environment["MONICA_DEFAULTS_SUITE"] {
                return "com.monicahq.ios.auth.\(suite)"
            }
        #endif
        return "com.monicahq.ios.auth"
    }

    /// How the phone is named in the "Mobile apps" list of the web's security settings. iOS no
    /// longer gives apps the name the person chose, so the model and the system version say which
    /// device it is.
    private static func deviceName() -> String {
        "\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)"
    }
}
