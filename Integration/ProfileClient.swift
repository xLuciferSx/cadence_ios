import Foundation
import Dependencies
import KeyboardFoundation

/// Reads/writes the per-user account data (settings, dictionary, snippets) that
/// the backend persists. Uses the account access token stored by AuthClient in
/// the shared App Group. See INTEGRATION.md for wiring the app's tabs to this.
public struct ProfileClient: Sendable {
  public var profile: @Sendable () async throws -> Profile
  public var updateSettings: @Sendable (_ patch: SettingsPatch) async throws -> Settings
  public var addWord: @Sendable (_ word: String, _ replacement: String?) async throws -> Void
  public var deleteWord: @Sendable (_ id: String) async throws -> Void
  public var addSnippet: @Sendable (_ title: String, _ content: String) async throws -> Void
  public var deleteSnippet: @Sendable (_ id: String) async throws -> Void
}

public struct Profile: Sendable, Equatable, Decodable {
  public let settings: Settings
  public let dictionary: [DictionaryEntry]
  public let snippets: [Snippet]
}

public struct Settings: Sendable, Equatable, Decodable {
  public var theme: String
  public var defaultTone: String
  public var languageBlend: Bool
  public var contextMemory: Bool
  public var onDeviceOnly: Bool
  public var cleanupEnabled: Bool
  public var activeLanguages: [String]
}

public struct SettingsPatch: Sendable, Encodable {
  public var theme: String?
  public var defaultTone: String?
  public var languageBlend: Bool?
  public var contextMemory: Bool?
  public var onDeviceOnly: Bool?
  public var cleanupEnabled: Bool?
  public var activeLanguages: [String]?
  public init(theme: String? = nil, defaultTone: String? = nil, languageBlend: Bool? = nil,
              contextMemory: Bool? = nil, onDeviceOnly: Bool? = nil, cleanupEnabled: Bool? = nil,
              activeLanguages: [String]? = nil) {
    self.theme = theme; self.defaultTone = defaultTone; self.languageBlend = languageBlend
    self.contextMemory = contextMemory; self.onDeviceOnly = onDeviceOnly
    self.cleanupEnabled = cleanupEnabled; self.activeLanguages = activeLanguages
  }
}

public struct DictionaryEntry: Sendable, Equatable, Decodable, Identifiable {
  public let id: String
  public let word: String
  public let replacement: String?
}

public struct Snippet: Sendable, Equatable, Decodable, Identifiable {
  public let id: String
  public let title: String
  public let content: String
}

public extension ProfileClient {
  enum ProfileError: LocalizedError { case notConfigured, server(Int) }

  static func live(session: URLSession = .shared) -> ProfileClient {
    func accessToken() -> String? {
      UserDefaults(suiteName: AppConfig.appGroup)?.string(forKey: "accountAccessToken")
    }

    @Sendable func request(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> Data {
      guard let base = AppConfig.backendURL, let token = accessToken() else { throw ProfileError.notConfigured }
      var req = URLRequest(url: base.appendingPathComponent(path))
      req.httpMethod = method
      req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      if let body {
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
      }
      let (data, resp) = try await session.data(for: req)
      guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
        throw ProfileError.server((resp as? HTTPURLResponse)?.statusCode ?? -1)
      }
      return data
    }

    return ProfileClient(
      profile: {
        let data = try await request("v1/profile")
        return try JSONDecoder().decode(Profile.self, from: data)
      },
      updateSettings: { patch in
        let data = try await request("v1/settings", method: "PUT", body: patch)
        return try JSONDecoder().decode(Settings.self, from: data)
      },
      addWord: { word, replacement in
        _ = try await request("v1/dictionary", method: "POST", body: WordBody(word: word, replacement: replacement))
      },
      deleteWord: { id in _ = try await request("v1/dictionary/\(id)", method: "DELETE") },
      addSnippet: { title, content in
        _ = try await request("v1/snippets", method: "POST", body: SnippetBody(title: title, content: content))
      },
      deleteSnippet: { id in _ = try await request("v1/snippets/\(id)", method: "DELETE") }
    )
  }

  private struct WordBody: Encodable { let word: String; let replacement: String? }
  private struct SnippetBody: Encodable { let title: String; let content: String }
}

/// Type-erasing wrapper so `request` can take any Encodable body.
private struct AnyEncodable: Encodable {
  private let encode: (Encoder) throws -> Void
  init(_ wrapped: Encodable) { encode = wrapped.encode }
  func encode(to encoder: Encoder) throws { try encode(encoder) }
}

extension ProfileClient: DependencyKey {
  public static let liveValue = ProfileClient.live()
}

public extension DependencyValues {
  var profileClient: ProfileClient {
    get { self[ProfileClient.self] }
    set { self[ProfileClient.self] = newValue }
  }
}
