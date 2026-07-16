import AppKit
import SwiftUI
import TimezonerCore

struct TimezonePicker: NSViewRepresentable {
    let options: [TimezoneOption]
    @Binding var selection: String?

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.usesDataSource = true
        comboBox.dataSource = context.coordinator
        comboBox.delegate = context.coordinator
        comboBox.isEditable = true
        comboBox.completes = false
        comboBox.numberOfVisibleItems = 12
        comboBox.placeholderString = String(localized: "Choose a timezone")
        comboBox.setAccessibilityLabel(String(localized: "Timezone"))
        comboBox.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        context.coordinator.updateSelection(in: comboBox)
        return comboBox
    }

    func updateNSView(_ comboBox: NSComboBox, context: Context) {
        context.coordinator.parent = self
        if comboBox.currentEditor() == nil {
            context.coordinator.resetFilter()
            comboBox.reloadData()
            context.coordinator.updateSelection(in: comboBox)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSComboBoxDataSource, NSComboBoxDelegate, NSControlTextEditingDelegate {
        var parent: TimezonePicker
        private var filteredOptions: [TimezoneOption]

        init(parent: TimezonePicker) {
            self.parent = parent
            self.filteredOptions = parent.options
        }

        func numberOfItems(in comboBox: NSComboBox) -> Int {
            return filteredOptions.count
        }

        func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
            guard filteredOptions.indices.contains(index) else {
                return nil
            }
            return filteredOptions[index].pickerLabel
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else {
                return
            }
            let index = comboBox.indexOfSelectedItem
            guard filteredOptions.indices.contains(index) else {
                return
            }
            parent.selection = filteredOptions[index].identifier
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else {
                return
            }
            let query = comboBox.stringValue
            filteredOptions =
                query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? parent.options
                : parent.options.filter { option in
                    option.matches(searchQuery: query)
                }
            comboBox.reloadData()
            comboBox.noteNumberOfItemsChanged()
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else {
                return
            }
            let entered = normalized(comboBox.stringValue)
            let match =
                parent.options.first { option in
                    normalized(option.identifier) == entered || normalized(option.title) == entered
                        || normalized(option.pickerLabel) == entered
                } ?? (filteredOptions.count == 1 ? filteredOptions[0] : nil)

            if let match {
                parent.selection = match.identifier
            }
            resetFilter()
            comboBox.reloadData()
            updateSelection(in: comboBox)
        }

        func resetFilter() {
            filteredOptions = parent.options
        }

        func updateSelection(in comboBox: NSComboBox) {
            guard
                let identifier = parent.selection,
                let option = parent.options.first(where: { option in option.identifier == identifier })
            else {
                comboBox.stringValue = ""
                return
            }
            comboBox.stringValue = option.pickerLabel
        }

        private func normalized(_ text: String) -> String {
            return
                text
                .replacingOccurrences(of: "−", with: "-")
                .replacingOccurrences(of: "–", with: "-")
                .replacingOccurrences(of: "—", with: "-")
                .replacingOccurrences(of: "＋", with: "+")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
