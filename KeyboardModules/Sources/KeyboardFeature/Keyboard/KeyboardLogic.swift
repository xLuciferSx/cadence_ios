import ComposableArchitecture
import Foundation
import KeyboardFoundation
import Transcription
import Typing

enum ToneOption: String, CaseIterable, Equatable, Sendable {
  case casual, formal, shorten, expand

  var label: String {
    switch self {
    case .casual: "Casual"
    case .formal: "Formal"
    case .shorten: "Shorten"
    case .expand: "Expand"
    }
  }
}

@Reducer
struct KeyboardLogic {
  @Dependency(\.textDocument) var textDocument
  @Dependency(\.autocorrect) var autocorrect
  @Dependency(\.transcription) var transcription

  private enum CancelID { case tone }

  enum Shift: Equatable, Sendable { case disabled, enabled, locked }
  enum Mode: Equatable, Sendable { case letters, numbers, symbols }

  @ObservableState
  struct State: Equatable {
    var shift: Shift = .enabled
    var mode: Mode = .letters
    var suggestions: [String] = []
    var defaultSuggestion: String?
    var languageCodes: [String] = ["EN"]
    var languageCode: String = "EN"
    var customWords: [String] = []
    var shorthand: [String: String] = [:]
    var toneBarVisible = false
    var isRewriting = false
    var hasText = false
    var voice = VoiceLogic.State()

    var language: KeyboardLanguage { KeyboardLanguages.layout(for: languageCode) }
    var canSwitchLanguage: Bool { languageCodes.count > 1 }

    var rows: [[String]] {
      switch mode {
      case .letters:
        let base = language.rows
        return (shift == .disabled || !language.cased) ? base : base.map { $0.map { $0.uppercased() } }
      case .numbers:
        return [
          ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
          ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
          [".", ",", "?", "!", "'"],
        ]
      case .symbols:
        return [
          ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
          ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"],
          [".", ",", "?", "!", "'"],
        ]
      }
    }
  }

  enum Action: Equatable, Sendable {
    case refresh
    case key(String)
    case backspaceTapped
    case shiftTapped
    case letterModeTapped
    case numberModeTapped
    case symbolModeTapped
    case spaceTapped
    case returnTapped
    case globeTapped
    case globeLongPressed
    case openApp
    case toneBarToggled
    case toneSelected(ToneOption)
    case toneRewrote(String)
    case toneFailed(String)
    case suggestionTapped(String)
    case voice(VoiceLogic.Action)
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.voice, action: \.voice) {
      VoiceLogic()
    }

    Reduce { state, action in
      switch action {
      case .refresh:
        loadLanguages(&state)
        state.customWords = AppConfig.customWords
        state.shorthand = AppConfig.shorthandExpansions
        refreshState(&state)
        return .none

      case let .key(character):
        handleInput(character, &state)
        return .none

      case .spaceTapped:
        handleInput(" ", &state)
        return .none

      case .returnTapped:
        handleInput("\n", &state)
        return .none

      case .backspaceTapped:
        let before = textDocument.contextBeforeInput()
        textDocument.deleteBackward()
        refreshState(&state, before: String(before.dropLast()))
        return .none

      case .shiftTapped:
        state.shift = switch state.shift {
        case .disabled: .enabled
        case .enabled: .locked
        case .locked: .disabled
        }
        return .none

      case .letterModeTapped:
        state.mode = .letters
        return .none

      case .numberModeTapped:
        state.mode = .numbers
        return .none

      case .symbolModeTapped:
        state.mode = .symbols
        return .none

      case .globeTapped:
        guard state.canSwitchLanguage else {
          textDocument.advanceToNextInputMode()
          return .none
        }
        let index = state.languageCodes.firstIndex(of: state.languageCode) ?? 0
        state.languageCode = state.languageCodes[(index + 1) % state.languageCodes.count]
        state.mode = .letters
        return .none

      case .globeLongPressed:
        textDocument.advanceToNextInputMode()
        return .none

      case .openApp:
        // Opening the container app uses the responder-chain openURL trick, which
        // iOS silently drops without Allow Full Access. Tell the user instead of
        // looking broken.
        guard textDocument.hasFullAccess() else {
          state.voice.errorMessage = "Turn on Allow Full Access for Cadence in Settings → General → Keyboard → Keyboards to open the app."
          return .none
        }
        textDocument.openApp()
        return .none

      case .toneBarToggled:
        state.toneBarVisible.toggle()
        return .none

      case let .toneSelected(tone):
        let before = textDocument.contextBeforeInput()
        let segment = TypingEngine.lastParagraph(before: before)
        guard !segment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          state.toneBarVisible = false
          return .none
        }
        state.toneBarVisible = false
        state.isRewriting = true
        state.voice.errorMessage = nil
        return .run { send in
          let rewritten = try await transcription.tone(segment, tone.rawValue)
          await send(.toneRewrote(rewritten))
        } catch: { error, send in
          await send(.toneFailed(error.localizedDescription))
        }
        .cancellable(id: CancelID.tone)

      case let .toneRewrote(text):
        state.isRewriting = false
        let before = textDocument.contextBeforeInput()
        let segment = TypingEngine.lastParagraph(before: before)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for _ in 0 ..< segment.count { textDocument.deleteBackward() }
        textDocument.insert(trimmed)
        refreshState(&state, before: String(before.dropLast(segment.count)) + trimmed)
        return .none

      case let .toneFailed(message):
        state.isRewriting = false
        state.voice.errorMessage = message
        return .none

      case let .suggestionTapped(word):
        let before = textDocument.contextBeforeInput()
        let current = TypingEngine.currentWord(before: before)
        for _ in 0 ..< current.count { textDocument.deleteBackward() }
        textDocument.insert(word + " ")
        let newBefore = String(before.dropLast(current.count)) + word + " "
        refreshState(&state, before: newBefore)
        return .none

      case let .voice(.delegate(.insert(text))):
        let before = textDocument.contextBeforeInput()
        textDocument.insert(text)
        refreshState(&state, before: before + text)
        return .none

      case .voice:
        return .none
      }
    }
  }

  private func loadLanguages(_ state: inout State) {
    let codes = AppConfig.activeLanguageCodes.filter { code in
      KeyboardLanguages.all.contains { $0.code == code }
    }
    state.languageCodes = codes.isEmpty ? ["EN"] : codes
    if !state.languageCodes.contains(state.languageCode) {
      state.languageCode = state.languageCodes[0]
    }
  }

  private func handleInput(_ input: String, _ state: inout State) {
    let before = textDocument.contextBeforeInput()
    let traits = textDocument.traits()
    let language = state.language.checkerLanguage

    if let first = input.first, TypingEngine.isTerminator(first) {
      let word = TypingEngine.currentWord(before: before)
      if !word.isEmpty, let expansion = state.shorthand[word.lowercased()] {
        for _ in 0 ..< word.count { textDocument.deleteBackward() }
        textDocument.insert(expansion + input)
        refreshState(&state, before: String(before.dropLast(word.count)) + expansion + input, traits: traits)
        return
      }
    }

    let customWords = state.customWords
    let edit = TypingEngine.edit(inserting: input, before: before, traits: traits) { word in
      customWords.contains { $0.lowercased() == word.lowercased() }
        ? nil
        : autocorrect.correction(word, language)
    }
    for _ in 0 ..< edit.deleteBackward { textDocument.deleteBackward() }
    textDocument.insert(edit.insert)
    refreshState(&state, before: TypingEngine.apply(edit, to: before), traits: traits)
  }

  private func wordSuggestions(_ word: String, customWords: [String], language: String) -> [String] {
    let lower = word.lowercased()
    if customWords.contains(where: { $0.lowercased() == lower }) { return [] }

    var options: [String] = []
    func add(_ candidate: String) {
      guard !candidate.isEmpty, !options.contains(where: { $0.lowercased() == candidate.lowercased() }) else { return }
      options.append(candidate)
    }

    let customMatches = customWords.filter { $0.lowercased().hasPrefix(lower) }
    if !customMatches.isEmpty {
      add(word)
      customMatches.forEach(add)
    }
    if let grammar = TypingEngine.commonCorrection(word), grammar != word {
      add(word)
      add(grammar)
    }
    if word.count >= 2 {
      autocorrect.suggestions(word, language).forEach(add)
    }
    return Array(options.prefix(3))
  }

  private func refreshState(_ state: inout State) {
    refreshState(&state, before: textDocument.contextBeforeInput())
  }

  private func refreshState(_ state: inout State, before: String, traits: TextInputTraits? = nil) {
    let traits = traits ?? textDocument.traits()

    state.hasText = !TypingEngine.lastParagraph(before: before)
      .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

    if state.shift != .locked {
      state.shift = TypingEngine.shouldCapitalizeNext(before: before, mode: traits.capitalization)
        ? .enabled
        : .disabled
    }

    guard traits.autocorrect else {
      state.suggestions = []
      state.defaultSuggestion = nil
      return
    }
    let word = TypingEngine.currentWord(before: before)
    if word.isEmpty {
      state.suggestions = Predictions.nextWords(previous: TypingEngine.previousWord(before: before))
      state.defaultSuggestion = nil
      return
    }

    let language = state.language.checkerLanguage
    let isCustom = state.customWords.contains { $0.lowercased() == word.lowercased() }
    state.suggestions = wordSuggestions(word, customWords: state.customWords, language: language)

    // The candidate that will be auto-applied on space — highlighted like iOS.
    let autoApplied = isCustom ? nil : (TypingEngine.commonCorrection(word) ?? autocorrect.correction(word, language))
    state.defaultSuggestion = state.suggestions.first { $0 == autoApplied }
  }
}
