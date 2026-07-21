import Foundation

public struct KeyEdit: Equatable, Sendable {
  public var deleteBackward: Int
  public var insert: String

  public init(deleteBackward: Int, insert: String) {
    self.deleteBackward = deleteBackward
    self.insert = insert
  }
}

public enum TypingEngine {

  public static func edit(
    inserting input: String,
    before: String,
    traits: TextInputTraits,
    correction: (String) -> String?
  ) -> KeyEdit {
    guard let first = input.first else { return KeyEdit(deleteBackward: 0, insert: input) }

    if traits.smartDashes, input == "-", before.hasSuffix("-") {
      return KeyEdit(deleteBackward: 1, insert: "\u{2014}")
    }

    if traits.smartQuotes, input == "\"" {
      return KeyEdit(deleteBackward: 0, insert: opensQuote(before) ? "\u{201C}" : "\u{201D}")
    }

    if traits.smartQuotes, input == "'" {
      return KeyEdit(deleteBackward: 0, insert: opensQuote(before) ? "\u{2018}" : "\u{2019}")
    }

    if input == " ", qualifiesForPeriodShortcut(before) {
      return KeyEdit(deleteBackward: 1, insert: ". ")
    }

    if traits.autocorrect, isTerminator(first) {
      let word = currentWord(before: before)
      if let fix = commonCorrection(word) {
        return KeyEdit(deleteBackward: word.count, insert: fix + input)
      }
      if isCorrectable(word), let fix = correction(word), fix != word {
        return KeyEdit(deleteBackward: word.count, insert: fix + input)
      }
    }

    return KeyEdit(deleteBackward: 0, insert: input)
  }

  /// Deterministic grammar fixes the system keyboard applies even though the
  /// word isn't "misspelled": standalone `i` -> `I` and missing-apostrophe
  /// contractions. Returns nil when there's nothing to fix.
  public static func commonCorrection(_ word: String) -> String? {
    guard let fix = commonCorrections[word.lowercased()] else { return nil }
    if let first = word.first, first.isUppercase, let fixFirst = fix.first, fixFirst.isLowercase {
      return fixFirst.uppercased() + fix.dropFirst()
    }
    return fix
  }

  // Only unambiguous fixes — strings that are essentially never intended as-is.
  // Real words that depend on context (its, were, well, id, ill, lets, wed) are
  // deliberately excluded so we don't "correct" a valid word.
  private static let commonCorrections: [String: String] = [
    "i": "I",
    "im": "I'm", "ive": "I've",
    "youre": "you're", "youve": "you've", "youll": "you'll", "youd": "you'd",
    "hes": "he's", "shes": "she's", "thats": "that's", "whats": "what's",
    "wheres": "where's", "whos": "who's", "theres": "there's", "heres": "here's",
    "theyre": "they're", "theyve": "they've", "theyll": "they'll", "theyd": "they'd",
    "weve": "we've", "werent": "weren't",
    "dont": "don't", "doesnt": "doesn't", "didnt": "didn't", "cant": "can't", "wont": "won't",
    "isnt": "isn't", "arent": "aren't", "wasnt": "wasn't",
    "hasnt": "hasn't", "havent": "haven't", "hadnt": "hadn't",
    "wouldnt": "wouldn't", "couldnt": "couldn't", "shouldnt": "shouldn't", "mustnt": "mustn't",
    "couldve": "could've", "wouldve": "would've", "shouldve": "should've", "mustve": "must've",
    "thatll": "that'll", "itll": "it'll",
  ]

  public static func apply(_ edit: KeyEdit, to before: String) -> String {
    String(before.dropLast(edit.deleteBackward)) + edit.insert
  }

  /// The last completed word before the cursor (ignoring trailing whitespace),
  /// or nil if the text ends with punctuation or is empty.
  public static func previousWord(before: String) -> String? {
    let withoutTrailingSpace = String(before.reversed().drop(while: \.isWhitespace).reversed())
    guard !withoutTrailingSpace.isEmpty else { return nil }
    let word = currentWord(before: withoutTrailingSpace)
    return word.isEmpty ? nil : word
  }

  public static func lastParagraph(before: String) -> String {
    if let newline = before.lastIndex(of: "\n") {
      return String(before[before.index(after: newline)...])
    }
    return before
  }

  public static func currentWord(before: String) -> String {
    var reversed = ""
    for character in before.reversed() {
      if isWordCharacter(character) { reversed.append(character) } else { break }
    }
    return String(reversed.reversed())
  }

  public static func shouldCapitalizeNext(before: String, mode: CapitalizationMode) -> Bool {
    switch mode {
    case .none:
      return false
    case .allCharacters:
      return true
    case .words:
      return before.isEmpty || (before.last?.isWhitespace ?? true)
    case .sentences:
      if before.isEmpty { return true }
      if before.hasSuffix("\n") { return true }
      let trailingSpaces = before.reversed().prefix { $0 == " " }.count
      guard trailingSpaces >= 1 else { return false }
      let core = before.dropLast(trailingSpaces)
      guard let last = core.last else { return true }
      return ".!?".contains(last)
    }
  }

  public static func isWordCharacter(_ character: Character) -> Bool {
    character.isLetter || character == "'" || character == "\u{2019}"
  }

  public static func isTerminator(_ character: Character) -> Bool {
    character.isWhitespace || ".,!?;:".contains(character)
  }

  static func isCorrectable(_ word: String) -> Bool {
    word.count >= 2 && word.allSatisfy(\.isLetter)
  }

  static func qualifiesForPeriodShortcut(_ before: String) -> Bool {
    let characters = Array(before)
    guard characters.count >= 2, characters.last == " " else { return false }
    let preceding = characters[characters.count - 2]
    return preceding.isLetter || preceding.isNumber
  }

  static func opensQuote(_ before: String) -> Bool {
    guard let last = before.last else { return true }
    return last.isWhitespace || "([{".contains(last)
  }
}
