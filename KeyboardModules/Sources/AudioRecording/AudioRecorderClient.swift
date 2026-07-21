import AVFoundation
import Dependencies
import Foundation
import OSLog

private let log = Logger(subsystem: "com.raivisolehno.VoiceKeyboard", category: "Recorder")

public struct AudioRecorderClient: Sendable {
  public var start: @Sendable () async throws -> Void
  public var stop: @Sendable () async throws -> Data
  public var cancel: @Sendable () async -> Void

  public init(
    start: @escaping @Sendable () async throws -> Void,
    stop: @escaping @Sendable () async throws -> Data,
    cancel: @escaping @Sendable () async -> Void
  ) {
    self.start = start
    self.stop = stop
    self.cancel = cancel
  }
}

extension AudioRecorderClient: DependencyKey {
  public static let liveValue: AudioRecorderClient = {
    let recorder = Recorder()
    return AudioRecorderClient(
      start: { try await recorder.start() },
      stop: { try await recorder.stop() },
      cancel: { await recorder.cancel() }
    )
  }()

  public static let testValue = AudioRecorderClient(
    start: {},
    stop: { Data() },
    cancel: {}
  )
}

public extension DependencyValues {
  var audioRecorder: AudioRecorderClient {
    get { self[AudioRecorderClient.self] }
    set { self[AudioRecorderClient.self] = newValue }
  }
}

@MainActor
private final class Recorder {
  nonisolated init() {}

  private let engine = AVAudioEngine()
  private var file: AVAudioFile?
  private var url: URL?
  private var tapInstalled = false

  enum RecordingError: LocalizedError {
    case noPermission
    case sessionFailed(step: String, code: Int)
    case couldNotStart(detail: String)
    case noRecording

    var errorDescription: String? {
      switch self {
      case .noPermission:
        return "Mic permission is off. Open Cadence and allow the microphone."
      case let .sessionFailed(step, code):
        return "Mic \(step) failed (\(code)). Turn on Allow Full Access for Cadence."
      case let .couldNotStart(detail):
        return "Recorder wouldn't start — \(detail)."
      case .noRecording:
        return "Nothing was recorded."
      }
    }
  }

  private var permissionLabel: String {
    switch AVAudioApplication.shared.recordPermission {
    case .granted: return "mic granted"
    case .denied: return "mic denied"
    default: return "mic not granted to keyboard"
    }
  }

  func start() async throws {
    guard AVAudioApplication.shared.recordPermission == .granted else {
      throw RecordingError.noPermission
    }
    let session = AVAudioSession.sharedInstance()

    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("dictation-\(UUID().uuidString).m4a")

    // Recording from a keyboard extension is finicky: different iOS/host-app
    // combinations reject different session shapes. We capture with
    // `AVAudioEngine` + an input tap rather than `AVAudioRecorder`, because in
    // an extension `AVAudioRecorder.record()` silently returns false even when
    // permission is granted and an input route exists. The engine's input node
    // works where the recorder doesn't. We still try a sequence of session
    // configs, from "most compatible" to "most exclusive", and take the first
    // whose engine actually starts.
    let configs: [(category: AVAudioSession.Category, options: AVAudioSession.CategoryOptions, label: String)] = [
      (.playAndRecord, [.mixWithOthers, .defaultToSpeaker], "playAndRecord+mix"),
      (.record, [.mixWithOthers], "record+mix"),
      (.record, [], "record"),
    ]

    log.notice("start: \(configs.count) configs, \(self.permissionLabel, privacy: .public), input \(session.isInputAvailable ? "ok" : "none", privacy: .public)")

    var lastFailure = "no config attempted"
    for (index, config) in configs.enumerated() {
      if index > 0 {
        // Let the media server settle between attempts before reconfiguring.
        try? await Task.sleep(nanoseconds: 300_000_000)
      }
      log.notice("attempt \(index, privacy: .public): \(config.label, privacy: .public)")

      do {
        try session.setCategory(config.category, mode: .default, options: config.options)
      } catch let error as NSError {
        lastFailure = "setup \(config.label) (\(error.code))"
        log.error("\(lastFailure, privacy: .public)")
        continue
      }

      // `msrv` can be transient while the media server spins up — retry activation once.
      do {
        try session.setActive(true, options: [])
      } catch let error as NSError {
        if error.code == AVAudioSession.ErrorCode.mediaServicesFailed.rawValue {
          try? await Task.sleep(nanoseconds: 350_000_000)
          if (try? session.setActive(true, options: [])) == nil {
            lastFailure = "activate \(config.label) (msrv)"
            log.error("\(lastFailure, privacy: .public)")
            continue
          }
        } else {
          lastFailure = "activate \(config.label) (\(error.code))"
          log.error("\(lastFailure, privacy: .public)")
          continue
        }
      }

      let input = engine.inputNode
      let format = input.outputFormat(forBus: 0)
      log.notice("input format \(config.label, privacy: .public): \(format.sampleRate, privacy: .public)Hz \(format.channelCount, privacy: .public)ch")
      // A zero sample rate means the input route isn't actually live for this
      // config (common when the session shape isn't accepted) — skip it.
      guard format.sampleRate > 0, format.channelCount > 0 else {
        lastFailure = "no input \(config.label), \(permissionLabel), input \(session.isInputAvailable ? "ok" : "none")"
        log.error("\(lastFailure, privacy: .public)")
        continue
      }

      // Encode straight to AAC/m4a at the hardware format. Writing buffers in
      // the tap's own format avoids any sample-rate/channel conversion; the
      // backend accepts whatever rate we send.
      let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: format.sampleRate,
        AVNumberOfChannelsKey: format.channelCount,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
      ]
      let file: AVAudioFile
      do {
        file = try AVAudioFile(forWriting: fileURL, settings: settings)
      } catch let error as NSError {
        lastFailure = "file \(config.label) (\(error.code))"
        log.error("\(lastFailure, privacy: .public)")
        continue
      }
      self.file = file

      input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
        try? self?.file?.write(from: buffer)
      }
      tapInstalled = true

      engine.prepare()
      do {
        try engine.start()
      } catch let error as NSError {
        input.removeTap(onBus: 0)
        tapInstalled = false
        self.file = nil
        try? FileManager.default.removeItem(at: fileURL)
        lastFailure = "engine \(config.label) (\(error.code)), \(permissionLabel), input \(session.isInputAvailable ? "ok" : "none")"
        log.error("\(lastFailure, privacy: .public)")
        continue
      }

      log.notice("started on \(config.label, privacy: .public)")
      self.url = fileURL
      return
    }

    log.error("couldNotStart: \(lastFailure, privacy: .public)")
    throw RecordingError.couldNotStart(detail: lastFailure)
  }

  func stop() throws -> Data {
    guard let url else { throw RecordingError.noRecording }
    if tapInstalled {
      engine.inputNode.removeTap(onBus: 0)
      tapInstalled = false
    }
    engine.stop()
    self.file = nil // releasing the AVAudioFile flushes and finalizes the m4a
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    defer {
      try? FileManager.default.removeItem(at: url)
      self.url = nil
    }
    return try Data(contentsOf: url)
  }

  func cancel() {
    if tapInstalled {
      engine.inputNode.removeTap(onBus: 0)
      tapInstalled = false
    }
    engine.stop()
    file = nil
    if let url { try? FileManager.default.removeItem(at: url) }
    url = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}
