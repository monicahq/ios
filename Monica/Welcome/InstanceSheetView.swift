import SwiftUI

/// The sheet where a person chooses the address of their Monica instance. Stateless: the draft and
/// the error come from `state`, every action goes back through the closures.
///
/// Drawn as in the design (title, explanation, field, then the buttons), full height, on the opaque
/// card colour, rather than as a system form with Cancel and Save in a navigation bar: on iOS 26
/// that bar and the sheet's glass background fail the accessibility audit (contrast, Dynamic
/// Type), and so does text in a half-height sheet.
struct InstanceSheetView: View {
    let state: InstanceSheetState
    let onDraftChange: (String) -> Void
    let onReset: () -> Void
    let onDismiss: () -> Void
    let onSave: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("instance_sheet_title")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("instance_sheet_description")
                        .font(.subheadline)
                        .foregroundStyle(Color.muted)
                }
                .fixedSize(horizontal: false, vertical: true)
                AddressField(state: state, onDraftChange: onDraftChange, onSave: onSave)
                // Side by side as in the design; one under the other with the accessibility text
                // sizes, so no label is squeezed.
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    Button("instance_sheet_reset", action: onReset)
                        .buttonStyle(TextButtonStyle())
                        .disabled(state.isChecking)
                    Spacer(minLength: 0)
                    Button("instance_sheet_cancel", action: onDismiss)
                        .buttonStyle(TextButtonStyle())
                    Button("instance_sheet_save", action: onSave)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(state.isChecking)
                        .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: false)
                }
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .tint(Color.ink)
        .presentationDragIndicator(.visible)
        // Opaque: text on the default glass background has no guaranteed contrast.
        .presentationBackground(Color.card)
        // Focus stays on Save after a refused address: VoiceOver says why, at every refusal.
        .onChange(of: state.refusals) {
            if let error = state.error {
                AccessibilityNotification.Announcement(String(localized: error.message)).post()
            }
        }
        .onChange(of: state.isChecking) {
            if state.isChecking {
                AccessibilityNotification.Announcement(checking).post()
            }
        }
    }
}

extension InstanceSheetView {
    private var checking: String {
        String(format: String(localized: "instance_sheet_checking"), instanceHost(state.draft))
    }
}

private struct AddressField: View {
    let state: InstanceSheetState
    let onDraftChange: (String) -> Void
    let onSave: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Visible label; VoiceOver reads it as the field's own label instead.
            Text("instance_sheet_address")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.ink)
                .accessibilityHidden(true)
            // Wraps instead of scrolling sideways, so the whole address stays visible with a large
            // text size. A wrapping field types a new line on Return: that line means Save.
            TextField(
                "instance_sheet_address",
                text: Binding(
                    get: { state.draft },
                    set: { text in
                        onDraftChange(text.replacingOccurrences(of: "\n", with: ""))
                        if text.contains("\n") {
                            onSave()
                        }
                    }
                ),
                prompt: Text("instance_sheet_placeholder").foregroundStyle(Color.muted),
                axis: .vertical
            )
            .font(.body)
            .foregroundStyle(Color.ink)
            .keyboardType(.URL)
            .textContentType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($isFocused)
            // The address being checked stays the one shown.
            .disabled(state.isChecking)
            .accessibilityLabel(Text("instance_sheet_address"))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(Color.page, in: RoundedRectangle(cornerRadius: 6))
            // Muted rather than the design's hairline: a field's border needs 3:1.
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.muted, lineWidth: 1))
            // The text itself is one line high: a tap anywhere in the box (44 pt at least) focuses
            // the field. VoiceOver and Voice Control act on the field directly.
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onTapGesture { isFocused = true }
            if state.isChecking {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(String(format: String(localized: "instance_sheet_checking"), instanceHost(state.draft)))
                }
                .font(.footnote)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            } else if let error = state.error {
                // An icon and a sentence, not a colour, say what is wrong.
                Label {
                    Text(error.message)
                } icon: {
                    Image(systemName: "exclamationmark.circle")
                }
                .font(.footnote)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview("Light") {
    Color.page.sheet(isPresented: .constant(true)) {
        InstanceSheetView(
            state: InstanceSheetState(draft: "https://app.monicahq.com"),
            onDraftChange: { _ in }, onReset: {}, onDismiss: {}, onSave: {}
        )
    }
}

#Preview("Error, dark") {
    Color.page.sheet(isPresented: .constant(true)) {
        InstanceSheetView(
            state: InstanceSheetState(draft: "not an address", error: .invalidAddress),
            onDraftChange: { _ in }, onReset: {}, onDismiss: {}, onSave: {}
        )
    }
    .preferredColorScheme(.dark)
}
