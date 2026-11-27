import SwiftUI

/// Connects `NewVaultScreen` to its `NewVaultViewModel`, and hands the created vault back.
struct NewVaultRoute: View {
    @State var viewModel: NewVaultViewModel
    let onCreated: (Vault) -> Void
    let onClose: () -> Void

    var body: some View {
        NewVaultScreen(
            state: viewModel.state,
            onNameChange: { viewModel.changeName($0) },
            onDescriptionChange: { viewModel.changeDescription($0) },
            onColourChoose: { viewModel.chooseColour($0) },
            onMakeDefaultToggle: { viewModel.toggleMakeDefault() },
            onCreate: {
                Task {
                    if let vault = await viewModel.create() {
                        onCreated(vault)
                    }
                }
            },
            onCancel: {
                if viewModel.cancel() {
                    onClose()
                }
            },
            onConfirmDiscard: onClose,
            onKeepEditing: { viewModel.keepEditing() }
        )
    }
}

/// The form to create a vault. Stateless.
///
/// Drawn as the instance sheet (opaque background, its own Cancel), not as a system form with a
/// navigation bar, which fails the accessibility audit over the iOS 26 sheet glass. While
/// something is typed, swiping the sheet down does not close it: Cancel asks first.
struct NewVaultScreen: View {
    let state: NewVaultUiState
    let onNameChange: (String) -> Void
    let onDescriptionChange: (String) -> Void
    let onColourChoose: (VaultColour) -> Void
    let onMakeDefaultToggle: () -> Void
    let onCreate: () -> Void
    let onCancel: () -> Void
    let onConfirmDiscard: () -> Void
    let onKeepEditing: () -> Void

    private enum Field { case name, description }

    @FocusState private var focus: Field?
    @ScaledMetric private var swatchSize: CGFloat = 44

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Button("new_vault_cancel", action: onCancel)
                        .buttonStyle(TextButtonStyle())
                        .padding(.leading, -12)
                    Text("new_vault_title")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                nameField
                descriptionField
                colourPicker
                if state.offersDefault {
                    Toggle("new_vault_make_default", isOn: Binding(get: { state.makeDefault }, set: { _ in onMakeDefaultToggle() }))
                        .font(.body)
                        .foregroundStyle(Color.ink)
                        .tint(Color.primaryFill)
                        .frame(minHeight: 44)
                }
                if let message = state.generalError ?? state.connectionError.map({ String(localized: $0.message) }) {
                    ErrorText(message: message, withIcon: true)
                }
                Button(action: onCreate) {
                    if state.isSaving {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(Color.ink)
                            Text("new_vault_creating")
                        }
                    } else {
                        Text("new_vault_create")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!state.canCreate)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.groupedCard)
        .interactiveDismissDisabled(state.hasTypedSomething)
        // The VoiceOver escape gesture and Esc go through Cancel, which asks before losing text.
        .accessibilityAction(.escape) { onCancel() }
        .onAppear { focus = .name }
        .onChange(of: state.generalError) { announce(state.generalError) }
        .onChange(of: state.connectionError) { announce(state.connectionError.map { String(localized: $0.message) }) }
        .onChange(of: state.fieldErrors) {
            announce(state.fieldErrors["name"] ?? state.fieldErrors.values.first)
            if state.fieldErrors["name"] != nil {
                focus = .name
            } else if state.fieldErrors["description"] != nil {
                focus = .description
            }
        }
        // An alert rather than an action sheet: on iOS 26 the sheet drops its cancel button, and
        // "Keep editing" must stay visible.
        .alert(
            "new_vault_discard_title",
            isPresented: Binding(get: { state.isConfirmingDiscard }, set: {
                if !$0 {
                    onKeepEditing()
                }
            })
        ) {
            Button("new_vault_discard", role: .destructive, action: onConfirmDiscard)
            Button("new_vault_keep_editing", role: .cancel, action: onKeepEditing)
        } message: {
            Text("new_vault_discard_message")
        }
    }

    private func announce(_ message: String?) {
        if let message {
            AccessibilityNotification.Announcement(message).post()
        }
    }

    // MARK: Fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("new_vault_name")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.ink)
                .accessibilityHidden(true)
            TextField(
                String(localized: "new_vault_name"),
                text: Binding(get: { state.name }, set: { onNameChange($0) }),
                prompt: Text("new_vault_name").foregroundStyle(Color.groupedMuted)
            )
            .monicaField(hasError: state.fieldErrors["name"] != nil)
            .textInputAutocapitalization(.sentences)
            .submitLabel(.next)
            .focused($focus, equals: .name)
            .accessibilityHint(state.fieldErrors["name"].map { Text($0) } ?? Text(verbatim: ""))
            .onSubmit { focus = .description }
            .disabled(state.isSaving)
            if let error = state.fieldErrors["name"] {
                ErrorText(message: error)
            }
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("new_vault_description")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.ink)
                .accessibilityHidden(true)
            TextField(
                String(localized: "new_vault_description"),
                text: Binding(get: { state.description }, set: { onDescriptionChange($0) }),
                prompt: Text("new_vault_description").foregroundStyle(Color.groupedMuted),
                axis: .vertical
            )
            .lineLimit(3 ... 6)
            .monicaField(hasError: state.fieldErrors["description"] != nil)
            .focused($focus, equals: .description)
            .accessibilityHint(state.fieldErrors["description"].map { Text($0) } ?? Text(verbatim: ""))
            .disabled(state.isSaving)
            if let error = state.fieldErrors["description"] {
                ErrorText(message: error)
            }
        }
    }

    private var colourPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("new_vault_colour")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: swatchSize), spacing: 12, alignment: .leading)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(VaultColour.allCases, id: \.self) { colour in
                    let isSelected = colour == state.colour
                    Button { onColourChoose(colour) } label: {
                        Circle()
                            .fill(colour.initialColour)
                            .frame(width: swatchSize, height: swatchSize)
                            .overlay {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.bold))
                                        .foregroundStyle(Color.groupedCard)
                                }
                            }
                            .overlay {
                                // A ring around the selected colour, so it shows by more than the check.
                                Circle()
                                    .strokeBorder(Color.ink, lineWidth: isSelected ? 2 : 0)
                                    .padding(-4)
                            }
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(colour.spokenName))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            if let error = state.fieldErrors["colour"] {
                ErrorText(message: error)
            }
        }
    }
}

private extension View {
    /// A field drawn in the design system's colours, outlined at 3:1 so it reads as a control, and
    /// thicker when the instance refused it (not colour alone).
    func monicaField(hasError: Bool) -> some View {
        font(.body)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(Color.groupedPage, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(hasError ? Color.ink : Color.muted, lineWidth: hasError ? 2 : 1)
            )
    }
}

/// A message under a field, or above the button, in the instance's or the app's words.
private struct ErrorText: View {
    let message: String
    var withIcon = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.circle")
                .accessibilityHidden(true)
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(withIcon ? .subheadline : .footnote)
        .foregroundStyle(Color.ink)
    }
}

#Preview("New vault") {
    NewVaultScreen(
        state: NewVaultUiState(offersDefault: true),
        onNameChange: { _ in }, onDescriptionChange: { _ in }, onColourChoose: { _ in }, onMakeDefaultToggle: {},
        onCreate: {}, onCancel: {}, onConfirmDiscard: {}, onKeepEditing: {}
    )
}

#Preview("Refused, dark") {
    var state = NewVaultUiState(offersDefault: false)
    state.name = "Work"
    state.fieldErrors = ["name": "The free plan holds 1 vault, and this account already has it."]
    return NewVaultScreen(
        state: state,
        onNameChange: { _ in }, onDescriptionChange: { _ in }, onColourChoose: { _ in }, onMakeDefaultToggle: {},
        onCreate: {}, onCancel: {}, onConfirmDiscard: {}, onKeepEditing: {}
    )
    .preferredColorScheme(.dark)
}
