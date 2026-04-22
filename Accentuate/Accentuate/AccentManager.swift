import Cocoa

final class AccentManager: NSObject {
    static let shared = AccentManager()

    // Displayed in menu-bar order. IDs match JSON filename suffix (accent_{id}.json).
    let available: [(id: String, displayName: String)] = [
        ("british",  "British"),
        ("canadian", "Canadian"),
        ("french",   "French"),
        ("italian",  "Italian"),
        ("medieval", "Medieval"),
        ("roadman",  "Roadman"),
        ("scottish", "Scottish"),
        ("swedish",  "Swedish"),
    ]

    private static let selectionFilePath = "~/Library/Application Support/Accentuate/selected_accent.txt"

    private let defaultAccentID = "swedish"
    private let availableIDs: Set<String>
    private let selectionFileURL: URL

    private(set) var selectedID: String
    private(set) var currentEngine: AccentEngine?

    private override init() {
        availableIDs = Set(available.map(\.id))
        selectionFileURL = URL(
            fileURLWithPath: NSString(string: AccentManager.selectionFilePath).expandingTildeInPath
        )
        let id = AccentManager.readFile(at: selectionFileURL) ?? "swedish"
        let normalized = availableIDs.contains(id) ? id : "swedish"
        selectedID = normalized
        currentEngine = AccentEngine(name: normalized) ?? AccentEngine(name: "swedish")
    }

    func selectAccent(_ id: String) {
        let normalized = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard availableIDs.contains(normalized) else { return }
        writeFile(normalized)
        selectedID = normalized
        currentEngine = AccentEngine(name: normalized) ?? AccentEngine(name: defaultAccentID)
    }

    private static func readFile(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let raw = String(data: data, encoding: .utf8)
        else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func writeFile(_ id: String) {
        do {
            try FileManager.default.createDirectory(
                at: selectionFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try "\(id)\n".write(to: selectionFileURL, atomically: true, encoding: .utf8)
        } catch {}
    }
}
