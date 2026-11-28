import SwiftUI

/// Says that what a screen shows is the copy kept on the phone, and since when. Shows nothing while
/// the screen is up to date. Shared by every screen that reads offline (constitution, principle
/// VIII); its text is `staleNoticeText`. It only draws: the screen, which is always on screen,
/// announces it with `staleAnnouncement` when it appears or goes.
struct StaleNoticeView: View {
    let since: Date?

    @Environment(\.locale) private var locale

    var body: some View {
        if let since {
            // Moves on by itself: "1 minute ago" becomes "2 minutes ago".
            TimelineView(.everyMinute) { context in
                Label {
                    Text(staleNoticeText(since: since, now: context.date, locale: locale))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "icloud.slash")
                        .accessibilityHidden(true)
                }
                .font(.subheadline)
                .foregroundStyle(Color.groupedMuted)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview("Not up to date") {
    StaleNoticeView(since: .now.addingTimeInterval(-3 * 3600))
        .padding()
}

#Preview("Not up to date, dark, largest text") {
    StaleNoticeView(since: .now.addingTimeInterval(-3 * 3600))
        .padding()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility5)
}

#Preview("French") {
    StaleNoticeView(since: .now.addingTimeInterval(-3 * 3600))
        .padding()
        .environment(\.locale, Locale(identifier: "fr"))
}
