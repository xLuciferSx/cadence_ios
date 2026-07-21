import Foundation
import KeyboardFoundation
import Observation

struct DictionaryWord: Identifiable, Codable, Equatable {
  var id: UUID = UUID()
  var label: String
}

struct Snippet: Identifiable, Codable, Equatable {
  var id: UUID = UUID()
  var trigger: String
  var expansion: String
}

struct StylePreset: Identifiable, Equatable {
  let id: String
  let name: String
  let detail: String
  let preview: String
}

struct LanguageOption: Identifiable, Equatable {
  let code: String
  let name: String
  var id: String { code }
}

enum ThemePreference: String, CaseIterable, Identifiable {
  case system, light, dark
  var id: String { rawValue }
  var label: String {
    switch self {
    case .system: "System"
    case .light: "Light"
    case .dark: "Dark"
    }
  }
}

enum CadenceTab: String, CaseIterable, Identifiable {
  case home, dictionary, snippets, style, settings
  var id: String { rawValue }
  var icon: String {
    switch self {
    case .home: "house.fill"
    case .dictionary: "character.cursor.ibeam"
    case .snippets: "scissors"
    case .style: "textformat"
    case .settings: "gearshape.fill"
    }
  }
  var title: String {
    switch self {
    case .home: "Home"
    case .dictionary: "Dictionary"
    case .snippets: "Snippets"
    case .style: "Style"
    case .settings: "Settings"
    }
  }
}

enum CadenceCatalog {
  static let styles: [StylePreset] = [
    StylePreset(id: "formal", name: "Formal", detail: "Caps + punctuation, no contractions",
                preview: "Hi Sarah, thank you for the update. I will review it this afternoon."),
    StylePreset(id: "casual", name: "Casual", detail: "Relaxed punctuation, contractions kept",
                preview: "hey! thanks for the update, i'll take a look this afternoon"),
    StylePreset(id: "concise", name: "Concise", detail: "Trims filler words, gets to the point",
                preview: "Got it — reviewing this afternoon."),
  ]

  static let languages: [LanguageOption] = [
    LanguageOption(code: "EN", name: "English"),
    LanguageOption(code: "RU", name: "Russian"),
    LanguageOption(code: "LV", name: "Latvian"),
    LanguageOption(code: "ES", name: "Spanish"),
    LanguageOption(code: "FR", name: "French"),
    LanguageOption(code: "DE", name: "German"),
    LanguageOption(code: "HI", name: "Hindi"),
    LanguageOption(code: "AR", name: "Arabic"),
    LanguageOption(code: "JA", name: "Japanese"),
    LanguageOption(code: "ZH", name: "Mandarin"),
  ]

  static let nativeNames: [String: String] = [
    "EN": "English", "RU": "Русский", "LV": "Latviešu", "ES": "Español", "FR": "Français",
    "DE": "Deutsch", "HI": "हिन्दी", "AR": "العربية", "JA": "日本語", "ZH": "拼音",
  ]

  static func name(for code: String) -> String {
    languages.first { $0.code == code }?.name ?? code
  }
}

@Observable
final class CadenceStore {
  var selectedTab: CadenceTab = .home
  var accountEmail: String? { didSet { persistAccount() } }

  var dictionary: [DictionaryWord] { didSet { persist() } }
  var snippets: [Snippet] { didSet { persist() } }
  var selectedStyleID: String { didSet { persist() } }
  var activeLanguages: [String] { didSet { persist() } }
  var themePreference: ThemePreference { didSet { persist() } }
  var languageBlend: Bool { didSet { persist() } }
  var contextMemory: Bool { didSet { persist() } }
  var onDeviceOnly: Bool { didSet { persist() } }
  var teamSnippets: Bool { didSet { persist() } }
  var cleanupEnabled: Bool {
    didSet { AppConfig.sharedDefaults?.set(cleanupEnabled, forKey: AppConfig.DefaultsKey.cleanupEnabled) }
  }

  private var loaded = false
  private let defaults = UserDefaults.standard

  var selectedStyle: StylePreset {
    CadenceCatalog.styles.first { $0.id == selectedStyleID } ?? CadenceCatalog.styles[0]
  }

  var activeLanguageChips: [String] {
    activeLanguages.map { CadenceCatalog.nativeNames[$0] ?? $0 }
  }

  init() {
    accountEmail = UserDefaults.standard.string(forKey: "cadence.accountEmail")
    dictionary = Self.decode([DictionaryWord].self, "cadence.dictionary")
      ?? [.init(label: "Cadence"), .init(label: "btw → by the way"), .init(label: "Raivis")]
    snippets = Self.decode([Snippet].self, "cadence.snippets")
      ?? [
        .init(trigger: "my email", expansion: "raivis.olehno@proton.me"),
        .init(trigger: "meeting wrap-up", expansion: "Thanks all — recap and next steps coming shortly."),
      ]
    selectedStyleID = UserDefaults.standard.string(forKey: "cadence.style") ?? "formal"
    activeLanguages = Self.decodeShared([String].self, AppConfig.DefaultsKey.activeLanguages) ?? ["EN", "RU", "LV"]
    themePreference = ThemePreference(rawValue: UserDefaults.standard.string(forKey: "cadence.theme") ?? "")
      ?? .system
    languageBlend = UserDefaults.standard.object(forKey: "cadence.languageBlend") as? Bool ?? true
    contextMemory = UserDefaults.standard.object(forKey: "cadence.contextMemory") as? Bool ?? true
    onDeviceOnly = UserDefaults.standard.bool(forKey: "cadence.onDeviceOnly")
    teamSnippets = UserDefaults.standard.bool(forKey: "cadence.teamSnippets")
    cleanupEnabled = AppConfig.sharedDefaults?.bool(forKey: AppConfig.DefaultsKey.cleanupEnabled) ?? false
    loaded = true
    Self.encodeShared(activeLanguages, AppConfig.DefaultsKey.activeLanguages)
    syncDictionaryToShared()
  }

  var isSignedIn: Bool { accountEmail != nil }

  func signIn(email: String) {
    let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !normalized.isEmpty else { return }
    accountEmail = normalized
  }

  func signOut() {
    accountEmail = nil
  }

  private func syncDictionaryToShared() {
    var words: [String] = []
    var shorthand: [String: String] = [:]
    for entry in dictionary {
      let separators = ["→", "->"]
      let arrow = separators.first { entry.label.contains($0) }
      if let arrow {
        let parts = entry.label.components(separatedBy: arrow)
        let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
        let value = parts.dropFirst().joined(separator: arrow).trimmingCharacters(in: .whitespaces)
        if !key.isEmpty, !value.isEmpty { shorthand[key] = value }
      } else {
        let word = entry.label.trimmingCharacters(in: .whitespaces)
        if !word.isEmpty { words.append(word) }
      }
    }
    Self.encodeShared(words, AppConfig.DefaultsKey.customWords)
    Self.encodeShared(shorthand, AppConfig.DefaultsKey.shorthand)
  }

  func toggleLanguage(_ code: String) {
    if activeLanguages.contains(code) {
      guard activeLanguages.count > 1 else { return }
      activeLanguages.removeAll { $0 == code }
    } else {
      guard activeLanguages.count < 3 else { return }
      activeLanguages.append(code)
    }
  }

  func addWord(_ word: String, expandsTo note: String) {
    let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    let expansion = note.trimmingCharacters(in: .whitespacesAndNewlines)
    let label = expansion.isEmpty ? trimmed : "\(trimmed) → \(expansion)"
    dictionary.append(DictionaryWord(label: label))
  }

  func addSnippet(trigger: String, expansion: String) {
    let t = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
    let e = expansion.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !t.isEmpty, !e.isEmpty else { return }
    snippets.append(Snippet(trigger: t, expansion: e))
  }

  private func persist() {
    guard loaded else { return }
    Self.encode(dictionary, "cadence.dictionary")
    Self.encode(snippets, "cadence.snippets")
    Self.encodeShared(activeLanguages, AppConfig.DefaultsKey.activeLanguages)
    syncDictionaryToShared()
    defaults.set(selectedStyleID, forKey: "cadence.style")
    defaults.set(themePreference.rawValue, forKey: "cadence.theme")
    defaults.set(languageBlend, forKey: "cadence.languageBlend")
    defaults.set(contextMemory, forKey: "cadence.contextMemory")
    defaults.set(onDeviceOnly, forKey: "cadence.onDeviceOnly")
    defaults.set(teamSnippets, forKey: "cadence.teamSnippets")
  }

  private func persistAccount() {
    if let accountEmail {
      defaults.set(accountEmail, forKey: "cadence.accountEmail")
    } else {
      defaults.removeObject(forKey: "cadence.accountEmail")
    }
  }

  private static func encode<T: Encodable>(_ value: T, _ key: String) {
    if let data = try? JSONEncoder().encode(value) {
      UserDefaults.standard.set(data, forKey: key)
    }
  }

  private static func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
    guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
  }

  private static func encodeShared<T: Encodable>(_ value: T, _ key: String) {
    if let data = try? JSONEncoder().encode(value) {
      AppConfig.sharedDefaults?.set(data, forKey: key)
    }
  }

  private static func decodeShared<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
    guard let data = AppConfig.sharedDefaults?.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
  }
}
