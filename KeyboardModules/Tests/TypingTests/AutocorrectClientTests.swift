import XCTest

@testable import Typing

@MainActor
final class AutocorrectClientTests: XCTestCase {

  func testCorrectionFixesCommonTypo() {
    let fix = AutocorrectClient.liveValue.correction("teh", "en_US")
    XCTAssertEqual(fix, "the")
  }

  func testCorrectlySpelledWordHasNoCorrection() {
    XCTAssertNil(AutocorrectClient.liveValue.correction("hello", "en_US"))
  }

  func testSuggestionsShowCorrectionsForMisspelling() {
    let options = AutocorrectClient.liveValue.suggestions("teh", "en_US")
    XCTAssertEqual(options.first, "teh") // own spelling first, so it can be kept
    XCTAssertTrue(options.contains("the"))
  }

  func testSuggestionsForCorrectWordDoNotForceOwnSpellingFirst() {
    // "the" is spelled correctly, so the strip shows completions, not a keep-my-spelling entry.
    let options = AutocorrectClient.liveValue.suggestions("the", "en_US")
    XCTAssertFalse(options.contains("the"))
  }
}
