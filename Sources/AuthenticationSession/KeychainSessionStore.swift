import Foundation
import Security

/// A ``SessionStore`` in the keychain, readable once the device has been unlocked after boot.
///
/// `kSecAttrAccessibleAfterFirstUnlock`, so background launches — a widget refresh, a
/// background task — can read the session too. Keychain items survive deleting the app, so a
/// reinstall on the same device comes back as the same user.
public struct KeychainSessionStore: SessionStore {
    /// A keychain call that returned something other than success.
    public struct Failure: Error, Equatable, Sendable {
        /// The `OSStatus` the Security framework returned.
        public let status: OSStatus
    }

    /// The item is there but is not a session this version reads — written by another format,
    /// or damaged.
    ///
    /// Not removed on its own: whether to throw it away is the caller's decision. ``clear()``
    /// removes it, and so does `SessionAuthenticator.signOut()`.
    public struct UndecodableItem: Error, Equatable, Sendable {
        /// What the decoder said, for logs.
        public let reason: String
    }

    private let service: String
    private let account: String
    private let accessGroup: String?

    /// Creates a store.
    ///
    /// - Parameters:
    ///   - service: The keychain service the item is filed under.
    ///   - account: The keychain account the item is filed under.
    ///   - accessGroup: A keychain access group to share the session with — an app extension
    ///     such as a widget. `nil` keeps it to the app.
    public init(service: String = "AuthenticationSession", account: String = "session", accessGroup: String? = nil) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }

    /// Returns the stored session, or `nil` when there is none.
    ///
    /// - Throws: ``Failure`` when the keychain could not be read, and ``UndecodableItem`` when
    ///   an item is stored but is not a session. Neither means "no session".
    public func load() throws -> AuthSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw UndecodableItem(reason: "the item holds no data")
            }
            do {
                return try JSONDecoder().decode(AuthSession.self, from: data)
            } catch {
                throw UndecodableItem(reason: String(describing: error))
            }
        case errSecItemNotFound:
            return nil
        default:
            throw Failure(status: status)
        }
    }

    public func save(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let updated = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        switch updated {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            let added = SecItemAdd(baseQuery.merging(attributes) { _, new in new } as CFDictionary, nil)
            guard added == errSecSuccess else { throw Failure(status: added) }
        default:
            throw Failure(status: updated)
        }
    }

    public func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure(status: status)
        }
    }

    private var baseQuery: [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}
