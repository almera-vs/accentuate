#!/usr/bin/swift
// Registers Accentuate with macOS Text Input Sources so it appears
// in System Settings → Keyboard → Text Input → Edit → +
import Carbon

let url = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Input Methods/Accentuate.app")
guard FileManager.default.fileExists(atPath: url.path) else {
    print("✗ Not found at \(url.path) — run ./install.sh first")
    exit(1)
}

let status = TISRegisterInputSource(url as CFURL)
switch status {
case noErr:
    print("✓ Registered. Now go to:")
    print("  System Settings → Keyboard → Text Input → Edit → +")
    print("  Find 'Accentuate' and add it.")
case OSStatus(-50):
    print("✓ Already registered (paramErr = already known to system)")
    print("  Try: System Settings → Keyboard → Text Input → Edit → +")
default:
    print("✗ Registration failed with status \(status)")
    print("  Try logging out and back in instead.")
}
