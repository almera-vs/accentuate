import Cocoa

// NOTE: Do NOT add @main here. main.swift is the entry point so that we can
// create the IMKServer before NSApplication.shared.run() is called.
@objc(AppDelegate)
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Warm the accent engine on launch so the first keystroke has no latency.
        _ = AccentManager.shared
    }

    // Input methods are long-running background processes.
    // Prevent macOS from terminating us when the last window closes (we have none).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
