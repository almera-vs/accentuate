import Cocoa
import InputMethodKit

private typealias TextClient = IMKTextInput

@objc(AccentuateInputController)
class AccentuateInputController: IMKInputController {

    private var buffer = ""
    private let replacementRange = NSRange(location: NSNotFound, length: NSNotFound)
    private let passthroughModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
    private let sentenceTerminators: Set<Character> = [".", "!", "?"]

    // MARK: - Key handling

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown else { return false }

        let activeMods = event.modifierFlags.intersection(passthroughModifiers)
        if !activeMods.isEmpty {
            if !buffer.isEmpty { commitBuffer(to: sender) }
            return false
        }

        switch event.keyCode {
        case 51: return handleBackspace(client: sender)  // ⌫
        case 36: return handleReturn(client: sender)     // ↩
        case 53: return handleEscape(client: sender)     // ⎋
        default:
            guard let chars = event.characters, !chars.isEmpty else { return false }
            if chars.count != 1 {
                return handleInputText(chars, modifiers: event.modifierFlags, client: sender)
            }

            guard isPrintable(chars) else {
                if !buffer.isEmpty { commitBuffer(to: sender) }
                return false
            }

            return handlePrintableInput(chars, client: sender)
        }
    }

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        handleInputText(string, modifiers: [], client: sender)
    }

    override func inputText(_ string: String!, key keyCode: Int, modifiers flags: Int, client sender: Any!) -> Bool {
        let mods = NSEvent.ModifierFlags(rawValue: UInt(flags))
        return handleInputText(string, modifiers: mods, client: sender)
    }

    override func didCommand(by aSelector: Selector!, client sender: Any!) -> Bool {
        guard let aSelector else { return false }
        let command = NSStringFromSelector(aSelector)

        switch command {
        case "deleteBackward:":
            return handleBackspace(client: sender)
        case "insertSpace:", "insertSpaceIgnoringSubstitution:":
            return handlePrintableInput(" ", client: sender)
        case "insertTab:", "insertBacktab:", "insertTabIgnoringFieldEditor:":
            if !buffer.isEmpty { commitBuffer(to: sender) }
            return false
        case "insertNewline:", "insertLineBreak:", "insertNewlineIgnoringFieldEditor:":
            return handleReturn(client: sender)
        case "cancelOperation:":
            return handleEscape(client: sender)
        default:
            if !buffer.isEmpty { commitBuffer(to: sender) }
            return false
        }
    }

    // MARK: - IMK lifecycle

    override func deactivateServer(_ sender: Any!) {
        if !buffer.isEmpty { commitBuffer(to: sender) }
        super.deactivateServer(sender)
    }

    override func commitComposition(_ sender: Any!) {
        if !buffer.isEmpty { commitBuffer(to: sender) }
        super.commitComposition(sender)
    }

    // MARK: - Menu bar menu

    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "Accentuate")
        let manager = AccentManager.shared
        for accent in manager.available {
            let item = NSMenuItem(
                title: accent.displayName,
                action: #selector(didSelectAccent(_:)),
                keyEquivalent: ""
            )
            item.representedObject = accent.id
            item.target = self
            item.state = accent.id == manager.selectedID ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    @objc private func didSelectAccent(_ item: NSMenuItem) {
        guard let id = item.representedObject as? String else { return }
        AccentManager.shared.selectedID = id
    }

    // MARK: - Buffer operations

    private func appendToBuffer(_ chars: String, client sender: Any?) {
        buffer += chars
        setMarkedText(client: sender)
    }

    private func setMarkedText(client sender: Any?) {
        guard let client = sender as? TextClient else { return }
        if buffer.isEmpty {
            client.setMarkedText(
                "",
                selectionRange: NSRange(location: 0, length: 0),
                replacementRange: replacementRange
            )
            return
        }
        let attrs: [NSAttributedString.Key: Any] = [.underlineStyle: NSUnderlineStyle.single.rawValue]
        client.setMarkedText(
            NSAttributedString(string: buffer, attributes: attrs),
            selectionRange: NSRange(location: (buffer as NSString).length, length: 0),
            replacementRange: replacementRange
        )
    }

    private func handleInputText(_ string: String?, modifiers: NSEvent.ModifierFlags, client sender: Any?) -> Bool {
        guard let string, !string.isEmpty else { return false }

        let activeMods = modifiers.intersection(passthroughModifiers)
        if !activeMods.isEmpty {
            if !buffer.isEmpty { commitBuffer(to: sender) }
            return false
        }

        if string.count == 1 {
            guard isPrintable(string) else {
                if !buffer.isEmpty { commitBuffer(to: sender) }
                return false
            }
            return handlePrintableInput(string, client: sender)
        }

        return handleMultiCharacterInput(string, client: sender)
    }

    private func handleMultiCharacterInput(_ string: String, client sender: Any?) -> Bool {
        guard let client = sender as? TextClient else { return false }

        var handled = false

        for character in string {
            let token = String(character)

            if !isPrintable(token) {
                if !buffer.isEmpty { commitBuffer(to: sender) }
                client.insertText(token, replacementRange: replacementRange)
                handled = true
                continue
            }

            if handlePrintableInput(token, client: sender) {
                handled = true
                continue
            }

            client.insertText(token, replacementRange: replacementRange)
            handled = true
        }

        return handled
    }

    private func handlePrintableInput(_ token: String, client sender: Any?) -> Bool {
        guard let character = token.first else { return false }

        if buffer.isEmpty {
            guard isWordCharacter(token) else { return false }
            appendToBuffer(token, client: sender)
            return true
        }

        appendToBuffer(token, client: sender)

        if sentenceTerminators.contains(character) {
            commitBuffer(to: sender)
        }

        return true
    }

    private func transform(_ text: String) -> String {
        AccentManager.shared.currentEngine?.process(text) ?? text
    }

    private func commitBuffer(to sender: Any?) {
        guard !buffer.isEmpty else { return }
        (sender as? TextClient)?.insertText(
            transform(buffer),
            replacementRange: replacementRange
        )
        buffer = ""
    }

    // MARK: - Special key handlers

    private func handleBackspace(client sender: Any?) -> Bool {
        guard !buffer.isEmpty else { return false }
        buffer = String(buffer.dropLast())
        setMarkedText(client: sender)
        return true
    }

    private func handleReturn(client sender: Any?) -> Bool {
        if !buffer.isEmpty {
            (sender as? TextClient)?.insertText(
                transform(buffer),
                replacementRange: replacementRange
            )
            buffer = ""
        }
        return false  // let the app handle ↩ (submit / newline)
    }

    private func handleEscape(client sender: Any?) -> Bool {
        guard !buffer.isEmpty else { return false }
        (sender as? TextClient)?.setMarkedText(
            "",
            selectionRange: NSRange(location: 0, length: 0),
            replacementRange: replacementRange
        )
        buffer = ""
        return true
    }

    // MARK: - Character classification

    // Word characters begin composition. Apostrophe and hyphen are included
    // so contractions ("don't") and hyphenated words start naturally.
    private func isWordCharacter(_ s: String) -> Bool {
        guard let first = s.first else { return false }
        return first.isLetter || first.isNumber || first == "'" || first == "-"
    }

    // Rejects ASCII control characters and the private-use range macOS uses for
    // function/arrow key codes (0xF700–0xF8FF).
    private func isPrintable(_ s: String) -> Bool {
        return s.unicodeScalars.allSatisfy { scalar in
            let v = scalar.value
            guard v >= 0x20, v != 0x7F else { return false }
            guard v < 0xF700 || v > 0xF8FF else { return false }
            return true
        }
    }
}
