import Foundation

public struct KeyboardLanguage: Sendable, Equatable {
  public let code: String
  public let nativeName: String
  public let cased: Bool
  public let checkerLanguage: String
  public let rows: [[String]]

  public init(code: String, nativeName: String, cased: Bool, checkerLanguage: String, rows: [[String]]) {
    self.code = code
    self.nativeName = nativeName
    self.cased = cased
    self.checkerLanguage = checkerLanguage
    self.rows = rows
  }
}

public enum KeyboardLanguages {
  public static let all: [KeyboardLanguage] = [
    KeyboardLanguage(code: "EN", nativeName: "English", cased: true, checkerLanguage: "en_US", rows: [
      ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
      ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
      ["z", "x", "c", "v", "b", "n", "m"],
    ]),
    KeyboardLanguage(code: "RU", nativeName: "Русский", cased: true, checkerLanguage: "ru_RU", rows: [
      ["й", "ц", "у", "к", "е", "н", "г", "ш", "щ", "з", "х", "ъ"],
      ["ф", "ы", "в", "а", "п", "р", "о", "л", "д", "ж", "э"],
      ["я", "ч", "с", "м", "и", "т", "ь", "б", "ю"],
    ]),
    KeyboardLanguage(code: "LV", nativeName: "Latviešu", cased: true, checkerLanguage: "lv_LV", rows: [
      ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
      ["a", "s", "d", "f", "g", "h", "j", "k", "l", "š"],
      ["z", "x", "c", "v", "b", "n", "m", "ž"],
    ]),
    KeyboardLanguage(code: "ES", nativeName: "Español", cased: true, checkerLanguage: "es_ES", rows: [
      ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
      ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ñ"],
      ["z", "x", "c", "v", "b", "n", "m"],
    ]),
    KeyboardLanguage(code: "FR", nativeName: "Français", cased: true, checkerLanguage: "fr_FR", rows: [
      ["a", "z", "e", "r", "t", "y", "u", "i", "o", "p"],
      ["q", "s", "d", "f", "g", "h", "j", "k", "l", "m"],
      ["w", "x", "c", "v", "b", "n"],
    ]),
    KeyboardLanguage(code: "DE", nativeName: "Deutsch", cased: true, checkerLanguage: "de_DE", rows: [
      ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p"],
      ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
      ["y", "x", "c", "v", "b", "n", "m", "ü"],
    ]),
    KeyboardLanguage(code: "JA", nativeName: "日本語", cased: true, checkerLanguage: "en_US", rows: [
      ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
      ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
      ["z", "x", "c", "v", "b", "n", "m"],
    ]),
    KeyboardLanguage(code: "ZH", nativeName: "拼音", cased: true, checkerLanguage: "en_US", rows: [
      ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
      ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
      ["z", "x", "c", "v", "b", "n", "m"],
    ]),
    KeyboardLanguage(code: "HI", nativeName: "हिन्दी", cased: false, checkerLanguage: "hi_IN", rows: [
      ["ौ", "ै", "ा", "ी", "ू", "ब", "ह", "ग", "द", "ज"],
      ["ो", "े", "्", "ि", "ु", "प", "र", "क", "त", "च"],
      ["म", "न", "व", "ल", "स", "य"],
    ]),
    KeyboardLanguage(code: "AR", nativeName: "العربية", cased: false, checkerLanguage: "ar", rows: [
      ["ض", "ص", "ث", "ق", "ف", "غ", "ع", "ه", "خ", "ح"],
      ["ش", "س", "ي", "ب", "ل", "ا", "ت", "ن", "م", "ك"],
      ["ئ", "ء", "ر", "ى", "ة", "و"],
    ]),
  ]

  public static func layout(for code: String) -> KeyboardLanguage {
    all.first { $0.code == code } ?? all[0]
  }
}
