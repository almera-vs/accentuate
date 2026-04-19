import Foundation

// MARK: - Accent data model

/// Top-level structure that mirrors the BeeStation accent JSON schema.
/// All keys are optional because not every accent file uses every pass.
struct AccentData: Decodable {
    let words:     [String: StringOrArray]?   // full-word replacements
    let start:     [String: StringOrArray]?   // word-start replacements
    let end:       [String: StringOrArray]?   // word-end replacements
    let syllables: [String: StringOrArray]?   // anywhere (substring) replacements
    let appends:   [String]?                  // flavor phrases (1% chance in orig.)
}

/// Accent JSON values are either a plain string or an array of strings (random pick).
enum StringOrArray: Decodable {
    case string(String)
    case array([String])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let arr = try? c.decode([String].self) { self = .array(arr); return }
        self = .string(try c.decode(String.self))
    }

    /// Returns the single string, or a random element from the array.
    var value: String {
        switch self {
        case .string(let s): return s
        case .array(let a):  return a.randomElement() ?? ""
        }
    }
}

// MARK: - Engine

/// Swift port of BeeStation's handle_accented_speech / treat_message_accent system.
///
/// The original DM code applies four ordered passes, each backed by a section of the
/// accent JSON. The ordering is intentional: whole-word substitutions happen before
/// partial-word ones, preventing double-substitution artifacts.
///
/// Case is preserved by running each rule three times:
///   1. ALLCAPS key  → ALLCAPS value
///   2. Capitalized key → Capitalized value
///   3. lowercase key  → lowercase value
///
/// This mirrors the triple replacetextEx calls in the original DM source.
final class AccentEngine {
    let name: String
    private let data: AccentData

    init?(name: String) {
        self.name = name
        guard
            let url = Bundle.main.url(forResource: "accent_\(name)", withExtension: "json"),
            let raw  = try? Data(contentsOf: url),
            let data = try? JSONDecoder().decode(AccentData.self, from: raw)
        else { return nil }
        self.data = data
    }

    /// Transforms a full sentence through all accent passes and returns the result.
    ///
    /// Mirrors handle_accented_speech in the DM source exactly:
    ///   1. Prepend a space (ensures \b fires on the very first character).
    ///   2. Apply words → start → end → syllables passes in order.
    ///   3. Trim the leading space.
    ///   4. 1% chance: strip trailing sentence punctuation, append a flavor phrase.
    func process(_ sentence: String) -> String {
        var text = " \(sentence)"

        if let dict = data.words     { text = applyPass(text, dict: dict, mode: .fullWord)  }
        if let dict = data.start     { text = applyPass(text, dict: dict, mode: .wordStart) }
        if let dict = data.end       { text = applyPass(text, dict: dict, mode: .wordEnd)   }
        if let dict = data.syllables { text = applyPass(text, dict: dict, mode: .anywhere)  }

        text = text.trimmingCharacters(in: .whitespaces)

        // Mirrors: if(speech_data["appends"] && prob(1))
        if let appends = data.appends, !appends.isEmpty, Int.random(in: 0..<100) == 0,
           let phrase = appends.randomElement() {
            // DM uses regex([.!?]$) which removes exactly ONE trailing punctuation char.
            if let last = text.last, ".!?".contains(last) { text.removeLast() }
            text = "\(text), \(phrase)"
        }

        return text
    }

    // MARK: - Private

    private enum Mode { case fullWord, wordStart, wordEnd, anywhere }

    private func applyPass(_ text: String, dict: [String: StringOrArray], mode: Mode) -> String {
        dict.reduce(text) { applyRule($0, key: $1.key, value: $1.value.value, mode: mode) }
    }

    /// Applies one replacement rule with the correct number of case-preserving passes
    /// for each mode, matching the DM source exactly:
    ///
    ///   REGEX_FULLWORD  (lines 43-46): 3 passes — upper, capitalize, lower
    ///   REGEX_STARTWORD (lines 47-50): 3 passes — upper, capitalize, lower
    ///   REGEX_ENDWORD   (lines 51-53): 2 passes — upper, lower   ← NO capitalize
    ///   REGEX_ANY       (lines 54-56): 2 passes — upper, lower   ← NO capitalize
    private func applyRule(_ text: String, key: String, value: String, mode: Mode) -> String {
        switch mode {
        case .anywhere:
            // Literal substring replacement — no word-boundary anchors.
            var r = text
            r = r.replacingOccurrences(of: key.uppercased(), with: value.uppercased(), options: .literal)
            r = r.replacingOccurrences(of: key,              with: value,              options: .literal)
            return r
        case .wordEnd:
            // Two passes only — DM REGEX_ENDWORD has no capitalize line.
            return [(key.uppercased(), value.uppercased()), (key, value)]
                .reduce(text) { replaceWithBoundary($0, key: $1.0, value: $1.1, mode: mode) }
        case .fullWord, .wordStart:
            // Three passes — DM REGEX_FULLWORD and REGEX_STARTWORD both include capitalize.
            return [(key.uppercased(), value.uppercased()),
                    (firstUpperRest(key), firstUpperRest(value)),
                    (key, value)]
                .reduce(text) { replaceWithBoundary($0, key: $1.0, value: $1.1, mode: mode) }
        }
    }

    private func replaceWithBoundary(_ text: String, key: String, value: String, mode: Mode) -> String {
        let esc = NSRegularExpression.escapedPattern(for: key)
        let pattern: String
        switch mode {
        case .fullWord:  pattern = "\\b\(esc)\\b"
        case .wordStart: pattern = "\\b\(esc)"
        case .wordEnd:   pattern = "\(esc)\\b"
        case .anywhere:  fatalError("unreachable")
        }
        return text.replacingOccurrences(of: pattern, with: value, options: .regularExpression)
    }

    /// Uppercases only the first character, leaving the rest unchanged.
    /// This mirrors DM's capitalize() which differs from Swift's .capitalized
    /// (which lowercases all non-first characters).
    private func firstUpperRest(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }
}
