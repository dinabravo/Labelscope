import Foundation

/// A single allergen that was found in scanned text, and the specific phrase that
/// triggered the match (which may be an alias/derivative rather than the allergen's
/// own name, e.g. allergen "Milk" matched via the phrase "whey").
struct AllergenMatch: Identifiable, Hashable {
    /// Stable per-allergen identity (lowercased allergen), used to dedupe repeat alerts.
    var id: String { allergen.lowercased() }
    let allergen: String
    let matchedPhrase: String

    /// Whether the match was via the allergen's own name/plural rather than an alias.
    var isDirectMatch: Bool { matchedPhrase.lowercased() == allergen.lowercased() }
}

/// Turns a user-entered allergen into the set of ingredient-label phrases that
/// indicate its presence, and matches those phrases against scanned text.
enum AllergenMatcher {

    /// Canonical (singular, lowercase) allergen name -> common ingredient names / derivatives
    /// that a label uses instead of the allergen's plain name.
    static let aliases: [String: [String]] = [
        "milk": ["dairy", "lactose", "casein", "caseinate", "whey", "butter", "buttermilk",
                 "cream", "cheese", "ghee", "yogurt", "yoghurt", "custard"],
        "egg": ["albumin", "albumen", "ovalbumin", "mayonnaise", "meringue"],
        "peanut": ["groundnut", "groundnuts", "arachis"],
        "tree nut": ["almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut",
                     "brazil nut", "macadamia", "pine nut", "praline", "marzipan"],
        "wheat": ["gluten", "semolina", "spelt", "durum", "farina", "bulgur", "couscous"],
        "soy": ["soya", "soybean", "soybeans", "edamame", "tofu", "tempeh", "miso"],
        "fish": ["anchovy", "anchovies", "cod", "salmon", "tuna", "haddock", "surimi"],
        "shellfish": ["crustacean", "crustaceans", "shrimp", "prawn", "prawns", "crab",
                      "lobster", "crayfish", "langoustine"],
        "sesame": ["tahini"],
        "mustard": [],
        "celery": ["celeriac"],
        "lupin": ["lupine", "lupini"],
        "sulphite": ["sulfite", "sulfites", "sulphites", "sulfur dioxide", "sulphur dioxide"],
    ]

    /// Expands a user-entered allergen (e.g. "tree nuts") into the lowercase phrases to
    /// search for in scanned ingredient text (e.g. "tree nuts", "tree nut", "almond", ...).
    static func searchPhrases(for allergen: String) -> [String] {
        let trimmed = allergen.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }

        let singular = singularized(trimmed)
        var phrases: Set<String> = [trimmed, singular]
        for key in [trimmed, singular] {
            if let extra = aliases[key] {
                phrases.formUnion(extra)
            }
        }
        return Array(phrases)
    }

    /// Common irregular plurals worth covering (checked before the generic suffix rules).
    private static let irregularPlurals: [String: String] = [
        "leaves": "leaf", "loaves": "loaf", "halves": "half",
        "shelves": "shelf", "knives": "knife", "lives": "life", "wolves": "wolf",
    ]

    static func singularized(_ word: String) -> String {
        if let irregular = irregularPlurals[word] {
            return irregular
        }
        if word.hasSuffix("ies"), word.count > 3 {
            return String(word.dropLast(3)) + "y"
        }
        if word.hasSuffix("es"), word.count > 2 {
            return String(word.dropLast(2))
        }
        if word.hasSuffix("s"), word.count > 1 {
            return String(word.dropLast())
        }
        return word
    }

    /// Lowercases and replaces punctuation with spaces, collapsing whitespace, so that
    /// phrase matching sees clean word boundaries regardless of how OCR punctuated the text.
    static func normalize(_ raw: String) -> String {
        var result = ""
        result.reserveCapacity(raw.count)
        for ch in raw.lowercased() {
            result.append(ch.isLetter || ch.isNumber ? ch : " ")
        }
        return result.split(separator: " ").joined(separator: " ")
    }

    /// Whether `phrase` appears in `text` as a whole word (or, for multi-word phrases, a
    /// whole run of words) rather than as a fragment of a longer word — e.g. "wheat" matches
    /// "whole wheat flour" but not "buckwheat".
    static func containsPhrase(_ phrase: String, in text: String) -> Bool {
        rangeOfPhrase(phrase, in: text) != nil
    }

    /// Like `containsPhrase`, but returns where the match is, so the caller can draw a box
    /// around just that word/phrase instead of an entire line of text.
    static func rangeOfPhrase(_ phrase: String, in text: String) -> Range<String.Index>? {
        guard !phrase.isEmpty else { return nil }
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: phrase))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text.range(of: phrase, options: .caseInsensitive)
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        return Range(match.range, in: text)
    }
}
