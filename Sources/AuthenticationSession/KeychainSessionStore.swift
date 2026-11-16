import Foundation
import Security
import Authentication

/// A ``SessionStore`` in the keychain, readable once the device has been unlocked after boot.
///
/// `kSecAttrAccessibleAfterFirstUnlock`, so background launches — a widget refresh, a
/// background task — can read the session too. Keychain items survive deleting the app, so a
/// reinstall on the same device comes back as the same user.
///
/// Not `ThisDeviceOnly`, on purpose: a phone set up from an encrypted backup of the old one keeps
/// the session, and an anonymous account — which has nothing else to sign back in with — keeps
/// its records. Not synchronizable either: the item never goes to iCloud Keychain.
///
/// While the device's protected data is not available — before the first unlock, or during a
/// prewarmed launch while locked — ``load()`` throws ``ProtectedDataUnavailable`` instead of
/// answering "no session", even when the keychain said the item was not found.
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
    private let protectedData: any ProtectedDataAvailability

    /// Creates a store.
    ///
    /// - Parameters:
    ///   - service: The keychain service the item is filed under.
    ///   - account: The keychain account the item is filed under.
    ///   - accessGroup: A keychain access group to share the session with — an app extension
    ///     such as a widget. `nil` keeps it to the app. Each process keeps its own copy in
    ///     memory; a refresh checks the store first, so an extension holding a session the app
    ///     has since left neither writes it back nor removes the app's new one.
    ///   - protectedData: Asked before an item that was not found is reported as no session.
    ///     ``KeychainProtectedDataProbe`` by default.
    public init(
        service: String = "AuthenticationSession",
        account: String = "session",
        accessGroup: String? = nil,
        protectedData: any ProtectedDataAvailability = KeychainProtectedDataProbe()
    ) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
        self.protectedData = protectedData
    }

    /// Returns the stored session, or `nil` when there is none.
    ///
    /// - Throws: ``ProtectedDataUnavailable`` while the device's protected data is not available,
    ///   ``Failure`` when the keychain could not be read otherwise, and ``UndecodableItem`` when
    ///   an item is stored but is not a session. None of them means "no session".
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
            // Locked, the keychain can say "not found" for an item that is there.
            guard protectedData.isAvailable else { throw ProtectedDataUnavailable(status: status) }
            return nil
        default:
            throw Self.failure(status)
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
            guard added == errSecSuccess else { throw Self.failure(added) }
        default:
            throw Self.failure(updated)
        }
    }

    public func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Self.failure(status)
        }
    }

    private static func failure(_ status: OSStatus) -> any Error {
        status == errSecInteractionNotAllowed ? ProtectedDataUnavailable(status: status) : Failure(status: status)
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
