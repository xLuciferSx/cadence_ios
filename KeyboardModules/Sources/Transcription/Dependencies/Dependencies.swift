import Dependencies
import Foundation

extension TranscriptionClient: DependencyKey {
  public static let liveValue = TranscriptionClient.live()
  public static let testValue = TranscriptionClient.mock()
}

public extension DependencyValues {
  var transcription: TranscriptionClient {
    get { self[TranscriptionClient.self] }
    set { self[TranscriptionClient.self] = newValue }
  }
}
