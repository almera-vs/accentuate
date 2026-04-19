#!/usr/bin/swift
import Carbon

func strProp(_ src: TISInputSource, _ key: CFString) -> String {
    guard let ptr = TISGetInputSourceProperty(src, key) else { return "-" }
    return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
}
func boolProp(_ src: TISInputSource, _ key: CFString) -> Bool {
    guard let ptr = TISGetInputSourceProperty(src, key) else { return false }
    return Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue() == kCFBooleanTrue
}

let all = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
var found = false
for src in all {
    let id = strProp(src, kTISPropertyInputSourceID)
    if id.lowercased().contains("accentuate") {
        found = true
        print("FOUND:")
        print("  ID:      \(id)")
        print("  Name:    \(strProp(src, kTISPropertyLocalizedName))")
        print("  Enabled: \(boolProp(src, kTISPropertyInputSourceIsEnabled))")
        print("  Capable: \(boolProp(src, kTISPropertyInputSourceIsSelectCapable))")
    }
}
if !found { print("NOT found in \(all.count) registered sources.") }
