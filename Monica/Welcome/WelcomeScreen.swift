import SwiftUI

/// The first screen of the app: who Monica is, and the ways in (sign up, log in, choose the
/// instance). Stateless: it shows what it is given and reports taps through the closures.
struct WelcomeScreen: View {
    /// The address of the current instance, as shown to people (`app.monicahq.com`).
    let instanceHost: String
    let onSignUp: () -> Void
    let onLogIn: () -> Void
    let onInstanceSettings: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                // At least as tall as the screen, so the buttons sit at the bottom of tall screens,
                // and scrollable, so nothing is cut on small screens or with a large text size.
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        TopBar(onInstanceSettings: onInstanceSettings)
                        Brand()
                        Illustration()
                            .padding(.top, 16)
                        Introduction()
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }
                    Spacer(minLength: 24)
                    VStack(spacing: 0) {
                        Actions(onSignUp: onSignUp, onLogIn: onLogIn)
                            .padding(.horizontal, 24)
                        InstanceLine(host: instanceHost, onTap: onInstanceSettings)
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

#Preview("Light") {
    WelcomeScreen(instanceHost: "app.monicahq.com", onSignUp: {}, onLogIn: {}, onInstanceSettings: {})
}

#Preview("Dark") {
    WelcomeScreen(instanceHost: "app.monicahq.com", onSignUp: {}, onLogIn: {}, onInstanceSettings: {})
        .preferredColorScheme(.dark)
}

#Preview("French") {
    WelcomeScreen(instanceHost: "app.monicahq.com", onSignUp: {}, onLogIn: {}, onInstanceSettings: {})
        .environment(\.locale, Locale(identifier: "fr"))
}
