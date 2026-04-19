import Foundation

/// Singleton that loads accent engines and persists the user's selection across launches.
/// Shared state is safe here because IMKInputController instances are all created on the
/// main thread and accent switching is a coarse-grained operation.
final class AccentManager {
    static let shared = AccentManager()

    // Displayed in menu-bar order. IDs match the JSON filename suffix (accent_{id}.json).
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

    private let defaultsKey = "SelectedAccent"

    /// The engine for the currently selected accent. nil only if the JSON failed to load.
    private(set) var currentEngine: AccentEngine?

    var selectedID: String {
        get { UserDefaults.standard.string(forKey: defaultsKey) ?? "swedish" }
        set {
            guard newValue != selectedID else { return }
            UserDefaults.standard.set(newValue, forKey: defaultsKey)
            reload(newValue)
        }
    }

    private init() {
        reload(selectedID)
    }

    private func reload(_ id: String) {
        currentEngine = AccentEngine(name: id)
    }
}
