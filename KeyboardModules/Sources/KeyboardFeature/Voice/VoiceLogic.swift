import AudioRecording
import ComposableArchitecture
import Foundation
import Transcription

@Reducer
struct VoiceLogic {
  @Dependency(\.audioRecorder) var audioRecorder
  @Dependency(\.transcription) var transcription
  @Dependency(\.textDocument) var textDocument

  @ObservableState
  struct State: Equatable {
    enum Status: Equatable { case idle, recording, transcribing }
    var status: Status = .idle
    var errorMessage: String?
  }

  enum Action: Equatable, Sendable {
    case micButtonTapped
    case recordingStarted
    case transcriptionSucceeded(String)
    case failed(String)
    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {
      case insert(String)
    }
  }

  private enum CancelID { case recording }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .micButtonTapped:
        switch state.status {
        case .idle:
          state.errorMessage = nil
          // Mic capture from a keyboard extension needs Allow Full Access. Without
          // it the audio unit can't start (CoreAudio 'what') — check up front and
          // give a clear instruction instead of a cryptic recorder failure.
          guard textDocument.hasFullAccess() else {
            state.errorMessage = "Turn on Allow Full Access for Cadence in Settings → General → Keyboard → Keyboards to use the mic."
            return .none
          }
          state.status = .recording
          return .run { send in
            try await audioRecorder.start()
            await send(.recordingStarted)
          } catch: { error, send in
            await audioRecorder.cancel()
            await send(.failed(error.localizedDescription))
          }

        case .recording:
          state.status = .transcribing
          return .run { send in
            let audio = try await audioRecorder.stop()
            let raw = try await transcription.transcribe(audio)
            let text = transcription.cleanupEnabled()
              ? try await transcription.cleanUp(raw)
              : raw
            await send(.transcriptionSucceeded(text))
          } catch: { error, send in
            await audioRecorder.cancel()
            await send(.failed(error.localizedDescription))
          }
          .cancellable(id: CancelID.recording)

        case .transcribing:
          return .none
        }

      case .recordingStarted:
        return .none

      case let .transcriptionSucceeded(text):
        state.status = .idle
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .none }
        return .send(.delegate(.insert(trimmed)))

      case let .failed(message):
        state.status = .idle
        state.errorMessage = message
        return .none

      case .delegate:
        return .none
      }
    }
  }
}
