import Foundation
import KeyboardFoundation

public struct TranscriptionClient: Sendable {
  public var transcribe: @Sendable (_ audio: Data) async throws -> String
  public var cleanUp: @Sendable (_ text: String) async throws -> String
  public var tone: @Sendable (_ text: String, _ tone: String) async throws -> String
  public var cleanupEnabled: @Sendable () -> Bool

  public init(
    transcribe: @escaping @Sendable (Data) async throws -> String,
    cleanUp: @escaping @Sendable (String) async throws -> String,
    tone: @escaping @Sendable (String, String) async throws -> String,
    cleanupEnabled: @escaping @Sendable () -> Bool
  ) {
    self.transcribe = transcribe
    self.cleanUp = cleanUp
    self.tone = tone
    self.cleanupEnabled = cleanupEnabled
  }
}

public extension TranscriptionClient {
  static func live(session: URLSession = .shared) -> TranscriptionClient {
    TranscriptionClient(
      transcribe: { audio in try await backend(session).transcribe(audio: audio) },
      cleanUp: { text in try await backend(session).cleanUp(text) },
      tone: { text, tone in try await backend(session).tone(text, tone) },
      cleanupEnabled: {
        AppConfig.sharedDefaults?.bool(forKey: AppConfig.DefaultsKey.cleanupEnabled) ?? false
      }
    )
  }

  static func mock(
    transcript: String = "",
    cleaned: String = "",
    toned: String = "",
    cleanupEnabled: Bool = false
  ) -> TranscriptionClient {
    TranscriptionClient(
      transcribe: { _ in transcript },
      cleanUp: { _ in cleaned },
      tone: { _, _ in toned },
      cleanupEnabled: { cleanupEnabled }
    )
  }

  private static func backend(_ session: URLSession) throws -> BackendClient {
    let token = AppConfig.deviceToken
    guard let url = AppConfig.backendURL, !token.isEmpty else {
      throw BackendClient.Failure.notConfigured
    }
    return BackendClient(baseURL: url, token: token, session: session)
  }
}
