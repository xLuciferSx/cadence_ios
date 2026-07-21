import Foundation
import Security

public enum Keychain {

  private static let accessGroup: String? = {
    guard let prefix = teamPrefix() else { return nil }
    return "\(prefix).\(AppConfig.keychainGroupSuffix)"
  }()

  public static func save(_ value: String, service: String, account: String) {
    let delete = baseQuery(service: service, account: account)
    SecItemDelete(delete as CFDictionary)

    var add = baseQuery(service: service, account: account)
    add[kSecValueData as String] = Data(value.utf8)
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(add as CFDictionary, nil)
  }

  public static func read(service: String, account: String) -> String? {
    var query = baseQuery(service: service, account: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data,
          let string = String(data: data, encoding: .utf8) else {
      return nil
    }
    return string
  }

  public static func delete(service: String, account: String) {
    SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
  }

  private static func baseQuery(service: String, account: String) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    if let accessGroup {
      query[kSecAttrAccessGroup as String] = accessGroup
    }
    return query
  }

  private static func teamPrefix() -> String? {
    let probe: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: "team-prefix-probe",
      kSecAttrService as String: "team-prefix-probe",
      kSecReturnAttributes as String: true,
    ]
    var result: CFTypeRef?
    var status = SecItemCopyMatching(probe as CFDictionary, &result)
    if status == errSecItemNotFound {
      status = SecItemAdd(probe as CFDictionary, &result)
    }
    guard status == errSecSuccess,
          let attrs = result as? [String: Any],
          let group = attrs[kSecAttrAccessGroup as String] as? String else {
      return nil
    }
    return group.components(separatedBy: ".").first
  }
}
