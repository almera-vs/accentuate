import Cocoa
import InputMethodKit

// Use the bundleIdentifier initializer so IMK reads InputMethodServerControllerClass
// from Info.plist. The controllerClass: variant routes through _IMKServerLegacy which
// crashes on macOS 26 with SIGSEGV at 0x8 inside initWithName:controllerClass:delegateClass:.
let server = IMKServer(
    name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String,
    bundleIdentifier: Bundle.main.bundleIdentifier
)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// withExtendedLifetime guarantees server is not ARC-released before app.run() returns.
withExtendedLifetime(server) {
    app.run()
}
