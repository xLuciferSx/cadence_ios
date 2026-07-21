import Foundation
@_exported import Typing

public struct TextDocumentClient: Sendable {
  public var insert: @Sendable (String) -> Void
  public var deleteBackward: @Sendable () -> Void
  public var advanceToNextInputMode: @Sendable () -> Void
  public var openApp: @Sendable () -> Void
  public var contextBeforeInput: @Sendable () -> String
  public var traits: @Sendable () -> TextInputTraits
  public var hasFullAccess: @Sendable () -> Bool

  public init(
    insert: @escaping @Sendable (String) -> Void = { _ in },
    deleteBackward: @escaping @Sendable () -> Void = {},
    advanceToNextInputMode: @escaping @Sendable () -> Void = {},
    openApp: @escaping @Sendable () -> Void = {},
    contextBeforeInput: @escaping @Sendable () -> String = { "" },
    traits: @escaping @Sendable () -> TextInputTraits = { .default },
    hasFullAccess: @escaping @Sendable () -> Bool = { false }
  ) {
    self.insert = insert
    self.deleteBackward = deleteBackward
    self.advanceToNextInputMode = advanceToNextInputMode
    self.openApp = openApp
    self.contextBeforeInput = contextBeforeInput
    self.traits = traits
    self.hasFullAccess = hasFullAccess
  }
}
