import Dependencies
import Foundation
import UIKit

public struct AutocorrectClient: Sendable {
  /// Top spelling correction for a finished word, or nil if it's spelled fine.
  /// Used to auto-apply a fix when the user types a space or punctuation.
  public var correction: @Sendable (_ word: String, _ language: String) -> String?
  /// Candidate words to show in the strip while typing: spelling corrections for
  /// a misspelled word (own spelling first so it can be kept), otherwise
  /// completions of the partial word.
  public var suggestions: @Sendable (_ word: String, _ language: String) -> [String]

  public init(
    correction: @escaping @Sendable (String, String) -> String?,
    suggestions: @escaping @Sendable (String, String) -> [String]
  ) {
    self.correction = correction
    self.suggestions = suggestions
  }
}

extension AutocorrectClient: DependencyKey {
  public static let liveValue = AutocorrectClient(
    correction: { word, language in
      MainActor.assumeIsolated {
        let nsWord = word as NSString
        guard nsWord.length > 1 else { return nil }
        let lang = TextChecking.resolvedLanguage(language)
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: nsWord.length)
        let misspelled = checker.rangeOfMisspelledWord(
          in: word, range: range, startingAt: 0, wrap: false, language: lang
        )
        guard misspelled.location != NSNotFound else { return nil }
        let guesses = checker.guesses(forWordRange: range, in: word, language: lang) ?? []
        return guesses.first { $0.lowercased() != word.lowercased() }
      }
    },
    suggestions: { word, language in
      MainActor.assumeIsolated {
        let nsWord = word as NSString
        guard nsWord.length >= 2 else { return [] }
        let lang = TextChecking.resolvedLanguage(language)
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: nsWord.length)
        let misspelled = checker.rangeOfMisspelledWord(
          in: word, range: range, startingAt: 0, wrap: false, language: lang
        )

        if misspelled.location != NSNotFound {
          let guesses = (checker.guesses(forWordRange: range, in: word, language: lang) ?? [])
            .filter { $0.lowercased() != word.lowercased() }
          guard !guesses.isEmpty else { return [] }
          return Array(([word] + guesses).prefix(3))
        }

        let completions = (checker.completions(forPartialWordRange: range, in: word, language: lang) ?? [])
          .filter { $0.lowercased() != word.lowercased() }
        return Array(completions.prefix(3))
      }
    }
  )

  public static let testValue = AutocorrectClient(
    correction: { _, _ in nil },
    suggestions: { _, _ in [] }
  )
}

public extension DependencyValues {
  var autocorrect: AutocorrectClient {
    get { self[AutocorrectClient.self] }
    set { self[AutocorrectClient.self] = newValue }
  }
}

private enum TextChecking {
  static func resolvedLanguage(_ language: String) -> String {
    let available = UITextChecker.availableLanguages
    if available.contains(language) { return language }
    let base = String(language.prefix(2))
    return available.first { $0.hasPrefix(base) } ?? "en_US"
  }
}
