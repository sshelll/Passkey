// Keychain helper — store/fetch/delete passwords with Touch ID gate on fetch.
//
// The keychain item uses kSecAttrAccessibleWhenUnlockedThisDeviceOnly (device-bound,
// lost on restore). Touch ID is enforced by LAContext.evaluatePolicy on fetch rather
// than by a SecAccessControl flag on the item, which avoids the Hardened Runtime +
// Developer ID requirement that SecAccessControlCreateWithFlags(.biometryCurrentSet)
// imposes on CLI tools on macOS 15+.
//
// ponytail: to move the biometric gate into the Security layer itself (so that other
// processes also can't read the item without Touch ID), sign with --options runtime
// using a real Developer ID and switch back to SecAccessControlCreateWithFlags(.biometryCurrentSet).

@preconcurrency import LocalAuthentication
@preconcurrency import Security

enum KeychainError: Error, CustomStringConvertible {
  case biometricsUnavailable
  case authFailed(Error)
  case itemNotFound
  case invalidData
  case osStatus(OSStatus)

  var description: String {
    switch self {
    case .biometricsUnavailable: return "biometrics not available on this device"
    case .authFailed(let e): return e.localizedDescription
    case .itemNotFound: return "item not found in keychain"
    case .invalidData: return "keychain data is not valid UTF-8"
    case .osStatus(let s):
      return (SecCopyErrorMessageString(s, nil) as String?) ?? "OSStatus \(s)"
    }
  }
}

enum KeychainHelper {
  static func store(password: String, service: String, account: String, keychain: SecKeychain? = nil) throws {
    var deleteQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    if let kc = keychain {
      deleteQuery[kSecUseKeychain as String] = kc
    }
    SecItemDelete(deleteQuery as CFDictionary)

    var addQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecValueData as String: Data(password.utf8),
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]
    if let kc = keychain {
      addQuery[kSecUseKeychain as String] = kc
    }
    let status = SecItemAdd(addQuery as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainError.osStatus(status) }
  }

  // Blocks the calling thread while macOS shows the Touch ID sheet, then reads keychain.
  static func fetch(service: String, account: String, reason: String, keychain: SecKeychain? = nil) throws -> String {
    let ctx = LAContext()
    var canError: NSError?
    // NOTE: .deviceOwnerAuthenticationWithBiometrics will reject password authentication
    guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &canError) else {
      throw KeychainError.biometricsUnavailable
    }

    nonisolated(unsafe) var authError: Error?
    let sema = DispatchSemaphore(value: 0)
    ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) {
      success, err in
      if !success { authError = err }
      sema.signal()
    }
    sema.wait()
    if let e = authError { throw KeychainError.authFailed(e) }

    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    if let kc = keychain {
      query[kSecUseKeychain as String] = kc
      query[kSecMatchSearchList as String] = [kc]
    }
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    switch status {
    case errSecSuccess:
      guard let data = result as? Data, let pw = String(data: data, encoding: .utf8) else {
        throw KeychainError.invalidData
      }
      return pw
    case errSecItemNotFound:
      throw KeychainError.itemNotFound
    default:
      throw KeychainError.osStatus(status)
    }
  }

  static func delete(service: String, account: String, keychain: SecKeychain? = nil) throws {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    if let kc = keychain {
      query[kSecUseKeychain as String] = kc
      query[kSecMatchSearchList as String] = [kc]
    }
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.osStatus(status)
    }
  }
}
