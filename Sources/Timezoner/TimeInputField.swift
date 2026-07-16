import SwiftUI
import TimezonerCore

struct TimeInputField: View {
    let value: TimeOfDay
    let accessibilityName: String
    let isEnabled: Bool
    let onCommit: (TimeOfDay) -> Void

    @State private var draft: String
    @State private var previousModelText: String
    @State private var isInvalid = false
    @FocusState private var isFocused: Bool

    init(
        value: TimeOfDay,
        accessibilityName: String,
        isEnabled: Bool,
        onCommit: @escaping (TimeOfDay) -> Void
    ) {
        self.value = value
        self.accessibilityName = accessibilityName
        self.isEnabled = isEnabled
        self.onCommit = onCommit
        self._draft = State(initialValue: value.formatted)
        self._previousModelText = State(initialValue: value.formatted)
    }

    var body: some View {
        TextField("HH:mm", text: $draft)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced).weight(.medium))
            .multilineTextAlignment(.center)
            .frame(width: TimezonerTheme.timeFieldWidth, height: TimezonerTheme.timeFieldHeight)
            .focused($isFocused)
            .disabled(!isEnabled)
            .overlay {
                RoundedRectangle(cornerRadius: TimezonerTheme.controlCornerRadius)
                    .stroke(isInvalid ? Color.red : Color.clear, lineWidth: 1)
            }
            .accessibilityLabel(accessibilityName)
            .accessibilityHint(
                isInvalid
                    ? "Invalid time. Enter time using 24-hour HH colon mm format"
                    : "Enter time using 24-hour HH colon mm format"
            )
            .onSubmit {
                commitDraft()
            }
            .onChange(of: isFocused) { focused in
                if !focused {
                    commitDraft()
                }
            }
            .onChange(of: value) { newValue in
                let priorModelText = previousModelText
                previousModelText = newValue.formatted
                if !isFocused || draft == priorModelText {
                    draft = previousModelText
                    isInvalid = false
                }
            }
    }

    private func commitDraft() {
        guard let time = TimeOfDay(text: draft) else {
            draft = value.formatted
            isInvalid = true
            return
        }
        isInvalid = false
        draft = time.formatted
        onCommit(time)
    }
}
