import Cocoa

@objc(AppDelegate)
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = AccentManager.shared
        setupStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Status bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        }
        rebuildStatusMenu()
    }

    func rebuildStatusMenu() {
        let menu = NSMenu()
        let manager = AccentManager.shared
        let currentID = manager.selectedID
        if let button = statusItem?.button {
            button.title = currentID.prefix(2).capitalized
        }
        for accent in manager.available {
            let item = NSMenuItem(
                title: accent.displayName,
                action: #selector(didSelectAccentFromStatus(_:)),
                keyEquivalent: ""
            )
            item.representedObject = accent.id
            item.target = self
            item.state = accent.id == currentID ? .on : .off
            menu.addItem(item)
        }
        statusItem?.menu = menu
    }

    @objc private func didSelectAccentFromStatus(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        AccentManager.shared.selectAccent(id)
        rebuildStatusMenu()
    }

}
