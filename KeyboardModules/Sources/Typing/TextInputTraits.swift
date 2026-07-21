import Foundation

public enum CapitalizationMode: Sendable, Equatable {
  case none
  case words
  case sentences
  case allCharacters
}

public struct TextInputTraits: Sendable, Equatable {
  public var capitalization: CapitalizationMode
  public var autocorrect: Bool
  public var smartQuotes: Bool
  public var smartDashes: Bool
  public var language: String

  public init(
    capitalization: CapitalizationMode = .sentences,
    autocorrect: Bool = true,
    smartQuotes: Bool = true,
    smartDashes: Bool = true,
    language: String = "en_US"
  ) {
    self.capitalization = capitalization
    self.autocorrect = autocorrect
    self.smartQuotes = smartQuotes
    self.smartDashes = smartDashes
    self.language = language
  }

  public static let `default` = TextInputTraits()
}
