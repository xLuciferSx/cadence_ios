import Foundation

public enum AppConfig {
  public static let appGroup = "group.com.raivisolehno.VoiceKeyboard"

  public static let keychainGroupSuffix = "com.raivisolehno.VoiceKeyboard.shared"

  public static let tokenService = "com.raivisolehno.VoiceKeyboard.backendToken"
  public static let tokenAccount = "device-token"

  public static var sharedDefaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

  // MARK: - Fallback config (free/personal Apple Developer teams)
  //
  // App Groups and shared Keychain require a PAID Apple Developer membership.
  // On a free/personal team the app and keyboard extension can't share storage,
  // so the extension can't read what you set in the app's Settings screen.
  // These constants are used as a fallback so the keyboard still works. Edit
  // them for your build. On a paid team, the App Group / Keychain values win.
  public static let fallbackBackendURL = "https://poetic-forgiveness-production-4dd4.up.railway.app"
  public static let fallbackDeviceToken = "0b693d0ab74479cc33f86dfd69ae510df204e92dababec76"
  public static let fallbackLanguageCodes = ["EN", "RU", "LV"]

  public static var backendURL: URL? {
    let shared = sharedDefaults?.string(forKey: DefaultsKey.backendURL)
    let resolved = (shared?.isEmpty == false) ? shared! : fallbackBackendURL
    return resolved.isEmpty ? nil : URL(string: resolved)
  }

  public static var deviceToken: String {
    let stored = Keychain.read(service: tokenService, account: tokenAccount)
    return (stored?.isEmpty == false) ? stored! : fallbackDeviceToken
  }

  public static var activeLanguageCodes: [String] {
    let shared = decodeShared([String].self, DefaultsKey.activeLanguages) ?? []
    return shared.isEmpty ? fallbackLanguageCodes : shared
  }

  /// Custom single words the user added (proper nouns, terms) — used as
  /// completions and kept safe from autocorrect.
  public static var customWords: [String] {
    decodeShared([String].self, DefaultsKey.customWords) ?? []
  }

  /// Shorthand expansions (e.g. "btw" -> "by the way"), keyed lowercased.
  public static var shorthandExpansions: [String: String] {
    decodeShared([String: String].self, DefaultsKey.shorthand) ?? [:]
  }

  private static func decodeShared<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
    guard let data = sharedDefaults?.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
  }

  public enum DefaultsKey {
    public static let cleanupEnabled = "cleanupEnabled"
    public static let backendURL = "backendURL"
    public static let activeLanguages = "activeLanguages"
    public static let customWords = "customWords"
    public static let shorthand = "shorthand"
  }
}
