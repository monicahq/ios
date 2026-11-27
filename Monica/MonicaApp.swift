import SwiftUI

@main
struct MonicaApp: App {
    @State private var sessionManager: SessionManager
    @State private var welcome: WelcomeViewModel
    private let instanceRepository: InstanceRepository
    private let checker: InstanceChecker
    private let vaultRepository: VaultRepository

    init() {
        let defaults = UserDefaults.standard
        let keychain = KeychainSecretStore(service: "com.monicahq.ios.auth")
        keychain.wipeIfFreshInstall(defaults: defaults)
        let configuration = URLSessionConfiguration.ephemeral
        let instanceRepository = InstanceRepository(defaults: defaults)
        let checker = InstanceChecker(configuration: configuration, appVersion: appVersion, allowsHTTP: allowsHTTPInstances)
        let sessionManager = SessionManager(store: keychain, configuration: configuration, deviceName: Self.deviceName())
        self.instanceRepository = instanceRepository
        self.checker = checker
        vaultRepository = VaultRepository(sessionManager: sessionManager)
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
                vaultRepository: vaultRepository,
                makeAccount: { [sessionManager, instanceRepository, checker] in
                    AccountViewModel(sessionManager: sessionManager, instanceRepository: instanceRepository, checker: checker)
                }
            )
        }
    }

    /// How the phone is named in the "Mobile apps" list of the web's security settings. iOS no
    /// longer gives apps the name the person chose, so the model and the system version say which
    /// device it is.
    private static func deviceName() -> String {
        "\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)"
    }
}
