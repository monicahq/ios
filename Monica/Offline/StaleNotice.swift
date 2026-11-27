import Foundation

/// The line a screen shows while what it displays comes from the offline copy: "Not up to date.
/// Last updated 3 hours ago." In words, so it never depends on colour, and in the person's
/// language, the relative time included.
func staleNoticeText(since: Date, now: Date, locale: Locale) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = locale
    formatter.unitsStyle = .full
    let relative = formatter.localizedString(for: min(since, now), relativeTo: now)
    let template = bundle(for: locale).localizedString(forKey: "stale_notice", value: nil, table: nil)
    return String(format: template, locale: locale, relative)
}

/// What VoiceOver says when the "not up to date" line appears (its text) or goes ("Up to date."),
/// after `prefix` when something else must be said at the same moment, since a second announcement
/// would cut the first one off.
func staleAnnouncement(since: Date?, prefix: String? = nil, now: Date, locale: Locale) -> String {
    let stale = since.map { staleNoticeText(since: $0, now: now, locale: locale) }
        ?? bundle(for: locale).localizedString(forKey: "stale_notice_gone", value: nil, table: nil)
    return [prefix, stale].compactMap(\.self).joined(separator: " ")
}

/// The app's texts in `locale`'s language, English when the app does not speak it.
private func bundle(for locale: Locale) -> Bundle {
    for language in [locale.language.languageCode?.identifier, "en"].compactMap(\.self) {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path) {
            return bundle
        }
    }
    return .main
}
