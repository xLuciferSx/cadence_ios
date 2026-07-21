import AudioRecording
import ComposableArchitecture
import Transcription
import Typing
import XCTest

@testable import KeyboardFeature

@MainActor
final class KeyboardLogicTests: XCTestCase {

  private func fakeDocument(
    _ text: LockIsolated<String>,
    traits: TextInputTraits = .default,
    hasFullAccess: Bool = true
  ) -> TextDocumentClient {
    TextDocumentClient(
      insert: { s in text.withValue { $0 += s } },
      deleteBackward: { text.withValue { $0 = String($0.dropLast()) } },
      advanceToNextInputMode: {},
      contextBeforeInput: { text.value },
      traits: { traits },
      hasFullAccess: { hasFullAccess }
    )
  }

  func testShiftCyclesThroughStates() async {
    let store = TestStore(initialState: KeyboardLogic.State()) {
      KeyboardLogic()
    }
    await store.send(.shiftTapped) { $0.shift = .locked }
    await store.send(.shiftTapped) { $0.shift = .disabled }
    await store.send(.shiftTapped) { $0.shift = .enabled }
  }

  func testTypingInsertsAndDropsOneShotShift() async {
    let doc = LockIsolated("")
    let store = TestStore(initialState: KeyboardLogic.State()) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = fakeDocument(doc)
    }
    await store.send(.key("H")) { $0.shift = .disabled; $0.hasText = true }
    await store.send(.key("i"))
    XCTAssertEqual(doc.value, "Hi")
  }

  func testGlobeCyclesLanguages() async {
    let store = TestStore(initialState: KeyboardLogic.State(languageCodes: ["EN", "RU", "LV"], languageCode: "EN")) {
      KeyboardLogic()
    }
    await store.send(.globeTapped) { $0.languageCode = "RU" }
    await store.send(.globeTapped) { $0.languageCode = "LV" }
    await store.send(.globeTapped) { $0.languageCode = "EN" }
  }

  func testGlobeSwitchesSystemKeyboardWhenSingleLanguage() async {
    let advanced = LockIsolated(false)
    let store = TestStore(initialState: KeyboardLogic.State(languageCodes: ["EN"], languageCode: "EN")) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = TextDocumentClient(advanceToNextInputMode: { advanced.setValue(true) })
    }
    await store.send(.globeTapped)
    XCTAssertTrue(advanced.value)
  }

  func testOpenAppInvokesClient() async {
    let opened = LockIsolated(false)
    let store = TestStore(initialState: KeyboardLogic.State()) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = TextDocumentClient(openApp: { opened.setValue(true) }, hasFullAccess: { true })
    }
    await store.send(.openApp)
    XCTAssertTrue(opened.value)
  }

  func testOpenAppWithoutFullAccessSurfacesInstruction() async {
    let opened = LockIsolated(false)
    let store = TestStore(initialState: KeyboardLogic.State()) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = TextDocumentClient(openApp: { opened.setValue(true) }, hasFullAccess: { false })
    }
    await store.send(.openApp) {
      $0.voice.errorMessage = "Turn on Allow Full Access for Cadence in Settings → General → Keyboard → Keyboards to open the app."
    }
    XCTAssertFalse(opened.value)
  }

  func testDefaultSuggestionHighlightsAutoApplied() async {
    let doc = LockIsolated("dont")
    let store = TestStore(initialState: KeyboardLogic.State(shift: .disabled, languageCodes: ["EN", "RU", "LV"])) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = fakeDocument(doc)
    }
    await store.send(.refresh) {
      $0.hasText = true
      $0.suggestions = ["dont", "don't"]
      $0.defaultSuggestion = "don't"
    }
  }

  func testRowsFollowActiveLanguage() {
    var state = KeyboardLogic.State(shift: .disabled, languageCode: "RU")
    XCTAssertEqual(state.rows.first?.first, "й")
    state.languageCode = "EN"
    XCTAssertEqual(state.rows.first?.first, "q")
  }

  func testGrammarAutocorrectOnSpace() async {
    let doc = LockIsolated("im")
    let store = TestStore(initialState: KeyboardLogic.State(shift: .disabled, languageCodes: ["EN", "RU", "LV"])) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = fakeDocument(doc)
    }
    await store.send(.spaceTapped) {
      $0.hasText = true
      $0.suggestions = ["not", "going", "just"]
    }
    XCTAssertEqual(doc.value, "I'm ")
  }

  func testNextWordPredictionsAfterSpace() async {
    let doc = LockIsolated("thanks ")
    let store = TestStore(initialState: KeyboardLogic.State(shift: .disabled, languageCodes: ["EN", "RU", "LV"])) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = fakeDocument(doc)
    }
    await store.send(.refresh) {
      $0.hasText = true
      $0.suggestions = ["for", "so", "again"]
    }
  }

  func testCustomWordCompletionAndNoAutocorrect() async {
    let doc = LockIsolated("Rai")
    let store = TestStore(
      initialState: KeyboardLogic.State(shift: .disabled, customWords: ["Raivis"])
    ) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = fakeDocument(doc)
      $0.autocorrect = AutocorrectClient(correction: { _, _ in nil }, suggestions: { _, _ in [] })
    }
    await store.send(.key("v")) {
      $0.hasText = true
      $0.suggestions = ["Raiv", "Raivis"]
    }
    XCTAssertEqual(doc.value, "Raiv")
  }

  func testShorthandExpandsOnSpace() async {
    let doc = LockIsolated("btw")
    let store = TestStore(
      initialState: KeyboardLogic.State(shift: .disabled, shorthand: ["btw": "by the way"])
    ) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = fakeDocument(doc)
    }
    await store.send(.spaceTapped) {
      $0.hasText = true
      $0.suggestions = ["the", "to", "a"]
    }
    XCTAssertEqual(doc.value, "by the way ")
  }

  func testModeSwitching() async {
    let store = TestStore(initialState: KeyboardLogic.State()) {
      KeyboardLogic()
    }
    await store.send(.numberModeTapped) { $0.mode = .numbers }
    await store.send(.symbolModeTapped) { $0.mode = .symbols }
    await store.send(.letterModeTapped) { $0.mode = .letters }
  }

  func testDoubleSpaceProducesPeriod() async {
    let doc = LockIsolated("hello ")
    let store = TestStore(initialState: KeyboardLogic.State(shift: .disabled, languageCodes: ["EN", "RU", "LV"])) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = fakeDocument(doc)
    }
    await store.send(.spaceTapped) {
      $0.shift = .enabled
      $0.hasText = true
      $0.suggestions = ["I", "The", "Thanks"]
    }
    XCTAssertEqual(doc.value, "hello. ")
  }

  func testAutocorrectOnSpace() async {
    let doc = LockIsolated("teh")
    let store = TestStore(initialState: KeyboardLogic.State(shift: .disabled, languageCodes: ["EN", "RU", "LV"])) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = fakeDocument(doc)
      $0.autocorrect = AutocorrectClient(
        correction: { word, _ in word == "teh" ? "the" : nil },
        suggestions: { _, _ in [] }
      )
    }
    await store.send(.spaceTapped) {
      $0.hasText = true
      $0.suggestions = ["best", "same", "next"]
    }
    XCTAssertEqual(doc.value, "the ")
  }

  func testSuggestionsFromCompletions() async {
    let doc = LockIsolated("hel")
    let store = TestStore(initialState: KeyboardLogic.State(shift: .disabled, languageCodes: ["EN", "RU", "LV"])) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = fakeDocument(doc)
      $0.autocorrect = AutocorrectClient(
        correction: { _, _ in nil },
        suggestions: { word, _ in word == "hel" ? ["hello", "help", "held"] : [] }
      )
    }
    await store.send(.refresh) {
      $0.suggestions = ["hello", "help", "held"]
      $0.hasText = true
    }
  }

  func testSuggestionTappedReplacesWord() async {
    let doc = LockIsolated("hel")
    let store = TestStore(initialState: KeyboardLogic.State(shift: .disabled, languageCodes: ["EN", "RU", "LV"])) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = fakeDocument(doc)
    }
    await store.send(.suggestionTapped("hello")) {
      $0.hasText = true
      $0.suggestions = ["the", "to", "a"]
    }
    XCTAssertEqual(doc.value, "hello ")
  }

  func testVoiceHappyPathInsertsTranscript() async {
    let doc = LockIsolated("")
    let store = TestStore(initialState: KeyboardLogic.State(shift: .disabled, languageCodes: ["EN", "RU", "LV"])) {
      KeyboardLogic()
    } withDependencies: {
      $0.audioRecorder = AudioRecorderClient(start: {}, stop: { Data() }, cancel: {})
      $0.transcription = .mock(transcript: "hello world", cleanupEnabled: false)
      $0.textDocument = fakeDocument(doc)
    }

    await store.send(.voice(.micButtonTapped)) { $0.voice.status = .recording }
    await store.receive(.voice(.recordingStarted))

    await store.send(.voice(.micButtonTapped)) { $0.voice.status = .transcribing }
    await store.receive(.voice(.transcriptionSucceeded("hello world"))) { $0.voice.status = .idle }
    await store.receive(.voice(.delegate(.insert("hello world")))) { $0.hasText = true }

    XCTAssertEqual(doc.value, "hello world")
  }

  func testToneRewritesCurrentParagraph() async {
    let doc = LockIsolated("um so like i think its fine")
    let store = TestStore(initialState: KeyboardLogic.State(shift: .disabled, languageCodes: ["EN", "RU", "LV"])) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = fakeDocument(doc)
      $0.transcription = .mock(toned: "I think it's fine.")
    }
    await store.send(.toneBarToggled) { $0.toneBarVisible = true }
    await store.send(.toneSelected(.formal)) {
      $0.toneBarVisible = false
      $0.isRewriting = true
    }
    await store.receive(.toneRewrote("I think it's fine.")) {
      $0.isRewriting = false
      $0.hasText = true
      $0.suggestions = ["I", "The", "Thanks"]
    }
    XCTAssertEqual(doc.value, "I think it's fine.")
  }

  func testToneFailureSurfacesMessage() async {
    struct BoomError: LocalizedError { var errorDescription: String? { "no backend" } }
    let doc = LockIsolated("hello")
    let store = TestStore(initialState: KeyboardLogic.State(shift: .disabled, languageCodes: ["EN", "RU", "LV"])) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = fakeDocument(doc)
      $0.transcription = TranscriptionClient(
        transcribe: { _ in "" },
        cleanUp: { $0 },
        tone: { _, _ in throw BoomError() },
        cleanupEnabled: { false }
      )
    }
    await store.send(.toneSelected(.casual)) { $0.isRewriting = true }
    await store.receive(.toneFailed("no backend")) {
      $0.isRewriting = false
      $0.voice.errorMessage = "no backend"
    }
  }

  func testVoiceFailureSurfacesMessage() async {
    struct BoomError: LocalizedError { var errorDescription: String? { "no mic" } }
    let store = TestStore(initialState: KeyboardLogic.State()) {
      KeyboardLogic()
    } withDependencies: {
      $0.audioRecorder = AudioRecorderClient(start: { throw BoomError() }, stop: { Data() }, cancel: {})
      $0.textDocument = TextDocumentClient(hasFullAccess: { true })
    }
    await store.send(.voice(.micButtonTapped)) { $0.voice.status = .recording }
    await store.receive(.voice(.failed("no mic"))) {
      $0.voice.status = .idle
      $0.voice.errorMessage = "no mic"
    }
  }

  func testVoiceWithoutFullAccessSurfacesInstruction() async {
    let store = TestStore(initialState: KeyboardLogic.State()) {
      KeyboardLogic()
    } withDependencies: {
      $0.textDocument = TextDocumentClient(hasFullAccess: { false })
    }
    // No recorder is invoked and status stays idle; only an instructive message appears.
    await store.send(.voice(.micButtonTapped)) {
      $0.voice.errorMessage = "Turn on Allow Full Access for Cadence in Settings → General → Keyboard → Keyboards to use the mic."
    }
  }
}
