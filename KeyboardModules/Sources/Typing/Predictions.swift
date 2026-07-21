import Foundation

public enum Predictions {
  /// Likely next words given the previous completed word. Falls back to sentence
  /// starters at the start of a sentence and to common words otherwise.
  public static func nextWords(previous: String?) -> [String] {
    guard let previous, !previous.isEmpty else { return starters }
    if let follow = bigrams[previous.lowercased()] { return Array(follow.prefix(3)) }
    return Array(defaults.prefix(3))
  }

  static let starters = ["I", "The", "Thanks"]
  static let defaults = ["the", "to", "a"]

  static let bigrams: [String: [String]] = [
    "i": ["am", "have", "think"],
    "i'm": ["not", "going", "just"],
    "you": ["can", "are", "should"],
    "the": ["best", "same", "next"],
    "thanks": ["for", "so", "again"],
    "thank": ["you", "you!", "you."],
    "to": ["be", "the", "do"],
    "for": ["the", "you", "me"],
    "let's": ["do", "go", "catch"],
    "lets": ["do", "go", "catch"],
    "can": ["you", "we", "i"],
    "we": ["can", "should", "will"],
    "it": ["is", "was", "looks"],
    "this": ["is", "week", "one"],
    "have": ["a", "to", "been"],
    "will": ["be", "you", "have"],
    "is": ["the", "a", "not"],
    "are": ["you", "we", "not"],
    "on": ["the", "monday", "it"],
    "at": ["the", "home", "work"],
    "in": ["the", "a", "my"],
    "good": ["morning", "idea", "luck"],
    "see": ["you", "the", "if"],
    "how": ["are", "about", "much"],
    "what": ["is", "are", "do"],
    "when": ["are", "is", "you"],
    "sounds": ["good", "great", "like"],
    "looking": ["forward", "for", "good"],
    "please": ["let", "send", "see"],
    "hi": ["there", "everyone", "team"],
    "hey": ["there", "how", "can"],
    "no": ["problem", "worries", "thanks"],
    "yes": ["please", "of", "that"],
    "just": ["wanted", "a", "to"],
    "going": ["to", "be", "well"],
    "be": ["there", "the", "able"],
    "do": ["you", "the", "it"],
    "get": ["the", "it", "back"],
    "make": ["sure", "it", "a"],
    "need": ["to", "a", "the"],
    "want": ["to", "a", "you"],
    "here": ["is", "are", "to"],
    "sorry": ["for", "about", "i"],
    "great": ["thanks", "to", "idea"],
    "sure": ["thing", "i", "let"],
  ]
}
