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
    private let asciiWordRegex = try! NSRegularExpression(pattern: #"\b[A-Za-z][A-Za-z']*\b"#)

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

        if name == "swedish" {
            text = applyNordicFallback(text)
        }

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
        let orderedRules = dict.sorted {
            if $0.key.count != $1.key.count { return $0.key.count > $1.key.count }
            return $0.key < $1.key
        }
        return orderedRules.reduce(text) { applyRule($0, key: $1.key, value: $1.value.value, mode: mode) }
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
            let capKey = firstUpperRest(key)
            let capValue = firstUpperRest(value)
            let upperKey = key.uppercased()
            let upperValue = value.uppercased()

            // For single-letter keys (e.g. "i"), capitalize and uppercase keys are identical.
            // Prefer "Ja" over "JA" by skipping the all-caps replacement in that overlap case.
            let passes: [(String, String)]
            if capKey == upperKey {
                passes = [(capKey, capValue), (key, value)]
            } else {
                passes = [(upperKey, upperValue), (capKey, capValue), (key, value)]
            }

            return passes.reduce(text) { replaceWithBoundary($0, key: $1.0, value: $1.1, mode: mode) }
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

    private func applyNordicFallback(_ text: String) -> String {
        let protected = swedishProtectedTokens()
        let nsText = text as NSString
        let matches = asciiWordRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        let mutable = NSMutableString(string: text)

        for match in matches.reversed() {
            let word = nsText.substring(with: match.range)
            let lower = word.lowercased()

            if word.count < 4 || protected.contains(lower) {
                continue
            }

            let stylized = stylizeNordicWord(word)
            if stylized != word {
                mutable.replaceCharacters(in: match.range, with: stylized)
            }
        }

        return mutable as String
    }

    private func swedishProtectedTokens() -> Set<String> {
        guard let words = data.words else { return [] }

        var tokens = Set<String>()
        for value in words.values {
            let variants: [String]
            switch value {
            case .string(let s):
                variants = [s]
            case .array(let a):
                variants = a
            }

            for variant in variants {
                for token in variant.lowercased().split(whereSeparator: { ch in
                    !(ch.unicodeScalars.allSatisfy { $0.properties.isAlphabetic } || ch == "'")
                }) {
                    tokens.insert(String(token))
                }
            }
        }

        return tokens
    }

    private func stylizeNordicWord(_ word: String) -> String {
        let lower = word.lowercased()
        var styled = lower

        let replacements: [(String, String)] = [
            ("tion", "sjon"),
            ("sion", "sjon"),
            ("ae", "æ"),
            ("oe", "ø"),
            ("oo", "ø"),
            ("ou", "u"),
            ("ow", "å"),
            ("wh", "v"),
            ("th", "d"),
            ("qu", "kv"),
            ("ck", "k"),
            ("ph", "f"),
            ("w", "v")
        ]

        for (from, to) in replacements {
            styled = styled.replacingOccurrences(of: from, with: to)
        }

        // Soft vowel fallback for untouched words.
        // Keep Nordic flavor, but do not force a -> æ (only explicit ae -> æ above).
        if styled == lower {
            if styled.contains("e") {
                styled = replaceFirst(in: styled, target: "e", replacement: "ä")
            } else if styled.contains("i") {
                styled = replaceFirst(in: styled, target: "i", replacement: "y")
            } else if styled.contains("u") {
                styled = replaceFirst(in: styled, target: "u", replacement: "ø")
            } else if styled.contains("o") {
                styled = replaceFirst(in: styled, target: "o", replacement: "ø")
            }
        }

        return restoreCase(from: word, to: styled)
    }

    private func replaceFirst(in text: String, target: Character, replacement: Character) -> String {
        guard let idx = text.firstIndex(of: target) else { return text }
        var out = text
        out.replaceSubrange(idx...idx, with: String(replacement))
        return out
    }

    private func restoreCase(from original: String, to replacement: String) -> String {
        if original == original.uppercased() {
            return replacement.uppercased()
        }

        if original == firstUpperRest(original.lowercased()) {
            return firstUpperRest(replacement)
        }

        return replacement
    }

    /// Uppercases only the first character, leaving the rest unchanged.
    /// This mirrors DM's capitalize() which differs from Swift's .capitalized
    /// (which lowercases all non-first characters).
    private func firstUpperRest(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }
}
