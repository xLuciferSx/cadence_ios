import Foundation
import Dependencies
import KeyboardFoundation

/// Exchanges a provider (Google/Apple) token for Cadence app tokens, stores the
/// session, and reads the account/entitlement from `/v1/me`. The provider UI
/// (GoogleSignIn / Sign in with Apple) lives in the app; see INTEGRATION.md.
public struct AuthClient: Sendable {
  public var signInWithGoogle: @Sendable (_ idToken: String) async throws -> Session
  public var signInWithApple: @Sendable (_ identityToken: String, _ fullName: String?, _ email: String?) async throws -> Session
  public var refresh: @Sendable () async throws -> Session
  public var me: @Sendable () async throws -> Account
  public var signOut: @Sendable () async -> Void
  public var currentAccessToken: @Sendable () -> String?
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
