import AuthenticationServices
import SwiftUI

/// Connects `WelcomeScreen` to its `WelcomeViewModel`, and opens the instance's sign-in page in
/// iOS's authentication sheet when the view model asks for it.
struct WelcomeRoute: View {
    @State var viewModel: WelcomeViewModel

    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    var body: some View {
        WelcomeScreen(
            state: viewModel.state,
            onSignUp: { Task { await viewModel.signUp() } },
            onLogIn: { Task { await viewModel.logIn() } },
            onOpenInstanceSheet: { viewModel.openInstanceSheet() },
            onDraftChange: { viewModel.changeDraft($0) },
            onResetDraft: { viewModel.resetDraft() },
            onDismissInstanceSheet: { viewModel.dismissInstanceSheet() },
            onSaveInstance: { Task { await viewModel.saveInstance() } }
        )
        .onAppear { viewModel.appeared() }
        .task(id: pageToOpen) {
            if let pageToOpen {
                await open(pageToOpen)
            }
        }
    }

    private var pageToOpen: URL? {
        if case let .browsing(url) = viewModel.state.signIn {
            url
        } else {
            nil
        }
    }

    /// Shares Safari's cookies, so a person already signed in on the web only confirms.
    private func open(_ page: URL) async {
        do {
            let callback = try await webAuthenticationSession.authenticate(
                using: page,
                callback: .customScheme("com.monicahq.ios"),
                preferredBrowserSession: .shared,
                additionalHeaderFields: [:]
            )
            // Not in this task: it ends as soon as the state leaves `browsing`, which would cancel
            // the sign-in requests.
            Task { await viewModel.callbackReceived(callback) }
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            viewModel.browserCancelled()
        } catch is CancellationError {
            // The screen went away; nothing to report.
        } catch {
            viewModel.browserFailed()
        }
    }
}

/// The first screen of the app: who Monica is, and the ways in (sign up, log in, choose the
/// instance). Stateless: it shows `state` and reports taps through the closures.
struct WelcomeScreen: View {
    let state: WelcomeUiState
    let onSignUp: () -> Void
    let onLogIn: () -> Void
    let onOpenInstanceSheet: () -> Void
    let onDraftChange: (String) -> Void
    let onResetDraft: () -> Void
    let onDismissInstanceSheet: () -> Void
    let onSaveInstance: () -> Void

    var body: some View {
        content
            .sheet(isPresented: Binding(
                get: { state.sheet != nil },
                // Swiping the sheet down closes it without saving, like Cancel.
                set: { isPresented in
                    if !isPresented, state.sheet != nil {
                        onDismissInstanceSheet()
                    }
                }
            )) {
                if let sheet = state.sheet {
                    InstanceSheetView(
                        state: sheet,
                        onDraftChange: onDraftChange,
                        onReset: onResetDraft,
                        onDismiss: onDismissInstanceSheet,
                        onSave: onSaveInstance
                    )
                }
            }
    }

    private var content: some View {
        GeometryReader { proxy in
            ScrollView {
                // At least as tall as the screen, so the buttons sit at the bottom of tall screens,
                // and scrollable, so nothing is cut on small screens or with a large text size.
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        TopBar(onInstanceSettings: onOpenInstanceSheet)
                            .disabled(state.signIn.isBusy)
                        Brand()
                        Illustration()
                            .padding(.top, 16)
                        Introduction()
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }
                    Spacer(minLength: 24)
                    VStack(spacing: 0) {
                        SignInStatus(progress: state.signIn, host: instanceHost(state.instanceURL))
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                        Actions(onSignUp: onSignUp, onLogIn: onLogIn)
                            .disabled(state.signIn.isBusy)
                            .padding(.horizontal, 24)
                        InstanceLine(host: instanceHost(state.instanceURL), onTap: onOpenInstanceSheet)
                            .disabled(state.signIn.isBusy)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            .padding(.bottom, 16)
                    }
                }
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.page)
        // Shown in place of the home (after logging out, or a session that ended): VoiceOver
        // starts reading the new screen rather than staying where the old one was.
        .onAppear { AccessibilityNotification.ScreenChanged().post() }
    }
}

private struct TopBar: View {
    let onInstanceSettings: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: onInstanceSettings) {
                Label("welcome_instance_settings", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .foregroundStyle(Color.ink)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 64)
    }
}

private struct Brand: View {
    @ScaledMetric(relativeTo: .largeTitle) private var wordmarkSize = 30.0

    var body: some View {
        HStack(spacing: 12) {
            // Decorative: the name is written right next to it.
            Image(.logo)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 36)
                .accessibilityHidden(true)
            Text("app_name")
                .font(.system(size: wordmarkSize, weight: .semibold))
                .foregroundStyle(Color.ink)
        }
    }
}

private struct Illustration: View {
    var body: some View {
        Color.clear
            .aspectRatio(880.0 / 530.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                Image(.pandaWelcome)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel(Text("welcome_illustration"))
            }
            .clipped()
            // Fades the edges into the page, as the design's elliptical mask does (fully opaque up
            // to 62% of the radius).
            .mask {
                EllipticalGradient(
                    stops: [.init(color: .black, location: 0.62), .init(color: .clear, location: 1)],
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.71
                )
            }
    }
}

private struct Introduction: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("welcome_title")
                .font(.title.weight(.semibold))
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            Text("welcome_description")
                .font(.body)
                .foregroundStyle(Color.muted)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct Actions: View {
    let onSignUp: () -> Void
    let onLogIn: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button("welcome_sign_up", action: onSignUp)
                .buttonStyle(PrimaryButtonStyle())
            Button("welcome_log_in", action: onLogIn)
                .buttonStyle(OutlinedButtonStyle())
        }
    }
}

/// Where logging in stands: a progress line while the app works, announced to VoiceOver, or what
/// went wrong, which takes the VoiceOver focus so it is read right away.
private struct SignInStatus: View {
    let progress: SignInProgress
    let host: String

    @AccessibilityFocusState private var isErrorFocused: Bool

    var body: some View {
        Group {
            switch progress {
            case .checking, .browsing, .signingIn:
                HStack(spacing: 8) {
                    ProgressView()
                    Text(connecting)
                }
                .accessibilityElement(children: .combine)
            case let .failed(error):
                // An icon and a sentence, not a colour, say what is wrong.
                Label {
                    Text(error.message)
                } icon: {
                    Image(systemName: "exclamationmark.circle")
                }
                .accessibilityFocused($isErrorFocused)
            case .idle:
                EmptyView()
            }
        }
        .font(.subheadline)
        .foregroundStyle(Color.ink)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .task(id: progress) {
            switch progress {
            case .checking, .signingIn:
                AccessibilityNotification.Announcement(connecting).post()
            case .failed:
                // Once the error is laid out and the browser sheet has handed focus back; reset
                // first, so a second error in a row moves focus again.
                isErrorFocused = false
                try? await Task.sleep(for: .milliseconds(300))
                isErrorFocused = true
            case .idle, .browsing:
                break
            }
        }
    }

    private var connecting: String {
        String(format: String(localized: "welcome_connecting"), host)
    }
}

private struct InstanceLine: View {
    let host: String
    let onTap: () -> Void

    private var text: AttributedString {
        var hostStyle = AttributeContainer()
        hostStyle.foregroundColor = Color.ink
        hostStyle.font = .footnote.weight(.medium)
        let line = String(format: String(localized: "welcome_instance"), host)
        return highlight(line, part: host, with: hostStyle)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .foregroundStyle(Color.muted)
                    .accessibilityHidden(true)
                Text(text)
                    .foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)
            }
            .font(.footnote)
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("welcome_instance_settings"))
    }
}

@MainActor
private func welcomePreview(_ state: WelcomeUiState) -> some View {
    WelcomeScreen(
        state: state,
        onSignUp: {},
        onLogIn: {},
        onOpenInstanceSheet: {},
        onDraftChange: { _ in },
        onResetDraft: {},
        onDismissInstanceSheet: {},
        onSaveInstance: {}
    )
}

#Preview("Light") {
    welcomePreview(WelcomeUiState(instanceURL: defaultInstanceURL))
}

#Preview("Dark") {
    welcomePreview(WelcomeUiState(instanceURL: defaultInstanceURL))
        .preferredColorScheme(.dark)
}

#Preview("French") {
    welcomePreview(WelcomeUiState(instanceURL: defaultInstanceURL))
        .environment(\.locale, Locale(identifier: "fr"))
}

#Preview("Signing in") {
    welcomePreview(WelcomeUiState(instanceURL: defaultInstanceURL, signIn: .signingIn))
}

#Preview("Error") {
    welcomePreview(WelcomeUiState(instanceURL: defaultInstanceURL, signIn: .failed(.signUpUnfinished)))
}

#Preview("Instance sheet") {
    welcomePreview(WelcomeUiState(instanceURL: defaultInstanceURL, sheet: InstanceSheetState(draft: defaultInstanceURL)))
}
