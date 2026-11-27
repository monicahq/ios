import Foundation

/// Everything that can go wrong while checking an instance, signing in or using a session, as the
/// person is told about it. Each case has one message in the String Catalog; the system's own
/// error descriptions are never shown or logged, since they can be technical or carry addresses.
enum AuthError: Error, Equatable {
    case invalidAddress
    case httpsRequired
    case unreachable
    case timeout
    case certificate
    case moved
    case notMonica
    case monicaTooOld
    case appTooOld
    case noAppSignIn
    case registrationClosed
    case cancelled
    case signUpUnfinished
    case denied
    case signInFailed
    case signInExpired
    case sessionExpired
    case sessionEnded
    case notAllowed
    case unexpectedAnswer

    /// What the person reads, with the next step.
    var message: LocalizedStringResource {
        switch self {
        case .invalidAddress: "auth_error_invalid_address"
        case .httpsRequired: "auth_error_https_required"
        case .unreachable: "auth_error_unreachable"
        case .timeout: "auth_error_timeout"
        case .certificate: "auth_error_certificate"
        case .moved: "auth_error_moved"
        case .notMonica: "auth_error_not_monica"
        case .monicaTooOld: "auth_error_monica_too_old"
        case .appTooOld: "auth_error_app_too_old"
        case .noAppSignIn: "auth_error_no_app_sign_in"
        case .registrationClosed: "auth_error_registration_closed"
        case .cancelled: "auth_error_cancelled"
        case .signUpUnfinished: "auth_error_sign_up_unfinished"
        case .denied: "auth_error_denied"
        case .signInFailed: "auth_error_sign_in_failed"
        case .signInExpired: "auth_error_sign_in_expired"
        case .sessionExpired: "auth_error_session_expired"
        case .sessionEnded: "auth_error_session_revoked"
        case .notAllowed: "auth_error_not_allowed"
        case .unexpectedAnswer: "auth_error_server"
        }
    }

    /// True when the instance could not be reached at all: the session is kept and the request can
    /// be tried again later.
    var isNetwork: Bool {
        [.unreachable, .timeout].contains(self)
    }

    /// The error a failed request stands for. Network failures keep their kind; anything else
    /// (cancelled tasks aside) is an answer the app did not expect.
    init(_ error: any Error) {
        if let error = error as? AuthError {
            self = error
            return
        }
        guard let error = error as? URLError else {
            self = .unexpectedAnswer
            return
        }
        switch error.code {
        case .timedOut:
            self = .timeout
        case .cannotFindHost, .cannotConnectToHost, .notConnectedToInternet, .networkConnectionLost,
             .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed, .callIsActive:
            self = .unreachable
        case .serverCertificateHasBadDate, .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid, .clientCertificateRejected, .clientCertificateRequired,
             .secureConnectionFailed, .appTransportSecurityRequiresSecureConnection:
            self = .certificate
        case .cancelled:
            self = .cancelled
        default:
            self = .unexpectedAnswer
        }
    }
}
