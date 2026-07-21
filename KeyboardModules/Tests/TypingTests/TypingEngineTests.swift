import XCTest

@testable import Typing

final class TypingEngineTests: XCTestCase {

  func testCurrentWordExtractsTrailingWord() {
    XCTAssertEqual(TypingEngine.currentWord(before: "hello wor"), "wor")
    XCTAssertEqual(TypingEngine.currentWord(before: "hello "), "")
    XCTAssertEqual(TypingEngine.currentWord(before: "don't"), "don't")
    XCTAssertEqual(TypingEngine.currentWord(before: ""), "")
  }

  func testSentenceCapitalization() {
    XCTAssertTrue(TypingEngine.shouldCapitalizeNext(before: "", mode: .sentences))
    XCTAssertTrue(TypingEngine.shouldCapitalizeNext(before: "Hi. ", mode: .sentences))
    XCTAssertTrue(TypingEngine.shouldCapitalizeNext(before: "Line\n", mode: .sentences))
    XCTAssertFalse(TypingEngine.shouldCapitalizeNext(before: "hello ", mode: .sentences))
    XCTAssertFalse(TypingEngine.shouldCapitalizeNext(before: "hell", mode: .sentences))
  }

  func testWordAndAllCharacterCapitalization() {
    XCTAssertTrue(TypingEngine.shouldCapitalizeNext(before: "hello ", mode: .words))
    XCTAssertFalse(TypingEngine.shouldCapitalizeNext(before: "hell", mode: .words))
    XCTAssertTrue(TypingEngine.shouldCapitalizeNext(before: "anything", mode: .allCharacters))
    XCTAssertFalse(TypingEngine.shouldCapitalizeNext(before: "", mode: .none))
  }

  func testDoubleSpaceInsertsPeriod() {
    let edit = TypingEngine.edit(inserting: " ", before: "hello ", traits: .default) { _ in nil }
    XCTAssertEqual(edit, KeyEdit(deleteBackward: 1, insert: ". "))
  }

  func testSingleSpaceIsPlainSpace() {
    let edit = TypingEngine.edit(inserting: " ", before: "hello", traits: .default) { _ in nil }
    XCTAssertEqual(edit, KeyEdit(deleteBackward: 0, insert: " "))
  }

  func testAutocorrectReplacesTrailingWordOnSpace() {
    let edit = TypingEngine.edit(inserting: " ", before: "teh", traits: .default) { word in
      word == "teh" ? "the" : nil
    }
    XCTAssertEqual(edit, KeyEdit(deleteBackward: 3, insert: "the "))
  }

  func testAutocorrectSkippedWhenDisabled() {
    let traits = TextInputTraits(autocorrect: false)
    let edit = TypingEngine.edit(inserting: " ", before: "teh", traits: traits) { _ in "the" }
    XCTAssertEqual(edit, KeyEdit(deleteBackward: 0, insert: " "))
  }

  func testSmartQuotesAndDashes() {
    let openQuote = TypingEngine.edit(inserting: "\"", before: "he said ", traits: .default) { _ in nil }
    XCTAssertEqual(openQuote.insert, "\u{201C}")
    let closeQuote = TypingEngine.edit(inserting: "\"", before: "\u{201C}hello", traits: .default) { _ in nil }
    XCTAssertEqual(closeQuote.insert, "\u{201D}")
    let apostrophe = TypingEngine.edit(inserting: "'", before: "don", traits: .default) { _ in nil }
    XCTAssertEqual(apostrophe.insert, "\u{2019}")
    let emDash = TypingEngine.edit(inserting: "-", before: "wait-", traits: .default) { _ in nil }
    XCTAssertEqual(emDash, KeyEdit(deleteBackward: 1, insert: "\u{2014}"))
  }

  func testCommonGrammarCorrections() {
    XCTAssertEqual(TypingEngine.commonCorrection("i"), "I")
    XCTAssertEqual(TypingEngine.commonCorrection("dont"), "don't")
    XCTAssertEqual(TypingEngine.commonCorrection("im"), "I'm")
    XCTAssertEqual(TypingEngine.commonCorrection("youre"), "you're")
    XCTAssertEqual(TypingEngine.commonCorrection("Dont"), "Don't")
    XCTAssertNil(TypingEngine.commonCorrection("hello"))
    XCTAssertNil(TypingEngine.commonCorrection("its")) // context-dependent, left alone
  }

  func testGrammarFixAppliesOnSpace() {
    let iFix = TypingEngine.edit(inserting: " ", before: "i", traits: .default) { _ in nil }
    XCTAssertEqual(iFix, KeyEdit(deleteBackward: 1, insert: "I "))
    let contraction = TypingEngine.edit(inserting: " ", before: "dont", traits: .default) { _ in nil }
    XCTAssertEqual(contraction, KeyEdit(deleteBackward: 4, insert: "don't "))
  }

  func testPreviousWordIgnoresTrailingSpace() {
    XCTAssertEqual(TypingEngine.previousWord(before: "I "), "I")
    XCTAssertEqual(TypingEngine.previousWord(before: "hello world "), "world")
    XCTAssertNil(TypingEngine.previousWord(before: "Hi. "))
    XCTAssertNil(TypingEngine.previousWord(before: ""))
  }

  func testNextWordPredictions() {
    XCTAssertEqual(Predictions.nextWords(previous: nil), ["I", "The", "Thanks"])
    XCTAssertEqual(Predictions.nextWords(previous: "I"), ["am", "have", "think"])
    XCTAssertEqual(Predictions.nextWords(previous: "thanks"), ["for", "so", "again"])
  }

  func testApplyProducesResultingText() {
    let edit = KeyEdit(deleteBackward: 3, insert: "the ")
    XCTAssertEqual(TypingEngine.apply(edit, to: "say teh"), "say the ")
  }
}
