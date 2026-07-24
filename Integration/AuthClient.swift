import Foundation
import Dependencies
import KeyboardFoundation

/// Email/password sign-in (primary), plus optional Google/Apple, exchanged for
/// Cadence app tokens. `config()` tells you which methods are enabled so the UI
/// can show/hide the social buttons (feature switch). See INTEGRATION.md.
public struct AuthClient: Sendable {
  public var register: @Sendable (_ email: String, _ password: String, _ name: String?) async throws -> Session
  public var signInWithEmail: @Sendable (_ email: String, _ password: String) async throws -> Session
  public var signInWithGoogle: @Sendable (_ idToken: String) async throws -> Session
  public var signInWithApple: @Sendable (_ identityToken: String, _ fullName: String?, _ email: String?) async throws -> Session
  public var refresh: @Sendable () async throws -> Session
  public var me: @Sendable () async throws -> Account
  public var config: @Sendable () async throws -> AuthMethods
  public var signOut: @Sendable () async -> Void
  public var currentAccessToken: @Sendable () -> String?
}

/// Which sign-in methods the backend has enabled (GET /auth/config).
public struct AuthMethods: Sendable, Equatable, Decodable {
  public let password: Bool
  public let google: Bool
  public let apple: Bool
}

public struct Session: Sendable, Equatable {
  public let accessToken: String
  public let refreshToken: String
}

public struct Account: Sendable, Equatable, Decodable {
  public struct User: Sendable, Equatable, Decodable {
    public let id: String; public let email: String; public let name: String?; public let plan: String
  }
  public struct Plan: Sendable, Equatable, Decodable { public let code: String; public let name: String }
  public struct Usage: Sendable, Equatable, Decodable {
    public let transcriptionSeconds: Int; public let cleanups: Int; public let tones: Int
  }
  public struct Remaining: Sendable, Equatable, Decodable {
    public let transcriptionSeconds: Int?; public let cleanups: Int?
  }
  public let user: User
  public let plan: Plan
  public let usage: Usage
  public let remaining: Remaining
  public var isPro: Bool { plan.code != "free" }
}

public extension AuthClient {
  static func live(session: URLSession = .shared) -> AuthClient {
    let store = TokenStore()

    @Sendable func post(_ path: String, _ body: [String: Any]) async throws -> Session {
      guard let base = AppConfig.backendURL else { throw AuthError.notConfigured }
      var req = URLRequest(url: base.appendingPathComponent(path))
      req.httpMethod = "POST"
      req.setValue("application/json", forHTTPHeaderField: "Content-Type")
      req.httpBody = try JSONSerialization.data(withJSONObject: body)
      let (data, resp) = try await session.data(for: req)
      guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
        throw AuthError.server
      }
      let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
      let s = Session(accessToken: decoded.accessToken, refreshToken: decoded.refreshToken)
      store.save(s)
      return s
    }

    return AuthClient(
      register: { email, password, name in
        var body: [String: Any] = ["email": email, "password": password]
        if let name, !name.isEmpty { body["name"] = name }
        return try await post("auth/register", body)
      },
      signInWithEmail: { email, password in
        try await post("auth/login", ["email": email, "password": password])
      },
      signInWithGoogle: { idToken in try await post("auth/google", ["idToken": idToken]) },
      signInWithApple: { token, name, email in
        var body: [String: Any] = ["identityToken": token]
        if let name { body["fullName"] = name }
        if let email { body["email"] = email }
        return try await post("auth/apple", body)
      },
      refresh: {
        guard let refresh = store.refreshToken else { throw AuthError.notConfigured }
        return try await post("auth/refresh", ["refreshToken": refresh])
      },
      me: {
        guard let base = AppConfig.backendURL, let access = store.accessToken else { throw AuthError.notConfigured }
        var req = URLRequest(url: base.appendingPathComponent("v1/me"))
        req.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 { throw AuthError.unauthorized }
        return try JSONDecoder().decode(Account.self, from: data)
      },
      config: {
        guard let base = AppConfig.backendURL else { throw AuthError.notConfigured }
        let (data, _) = try await session.data(from: base.appendingPathComponent("auth/config"))
        return try JSONDecoder().decode(AuthMethods.self, from: data)
      },
      signOut: { store.clear() },
      currentAccessToken: { store.accessToken }
    )
  }

  enum AuthError: LocalizedError { case notConfigured, server, unauthorized }

  private struct TokenResponse: Decodable { let accessToken: String; let refreshToken: String }
}

/// Stores tokens in the shared App Group so the keyboard extension can read the
/// access token too. For production, prefer the shared Keychain (see Keychain).
private struct TokenStore {
  private let defaults = UserDefaults(suiteName: AppConfig.appGroup)
  private let accessKey = "accountAccessToken"
  private let refreshKey = "accountRefreshToken"

  var accessToken: String? { defaults?.string(forKey: accessKey) }
  var refreshToken: String? { defaults?.string(forKey: refreshKey) }

  func save(_ s: Session) {
    defaults?.set(s.accessToken, forKey: accessKey)
    defaults?.set(s.refreshToken, forKey: refreshKey)
  }

  func clear() {
    defaults?.removeObject(forKey: accessKey)
    defaults?.removeObject(forKey: refreshKey)
  }
}

extension AuthClient: DependencyKey {
  public static let liveValue = AuthClient.live()
}

public extension DependencyValues {
  var auth: AuthClient {
    get { self[AuthClient.self] }
    set { self[AuthClient.self] = newValue }
  }
}
