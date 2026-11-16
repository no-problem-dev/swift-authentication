import Foundation
import Security

/// Whether the device's protected data — the keychain items a session lives in — can be read
/// right now.
///
/// Before the first unlock after a reboot, and while the device is locked, iOS can launch the
/// app without the person: prewarming (iOS 15 and later), a background task, a Live Activity.
/// The keychain then refuses reads with `errSecInteractionNotAllowed`, and on some versions
/// answers `errSecItemNotFound` for an item that is there. A store that trusted that answer
/// would report "no session", and the authenticator would open a new account over the person's.
///
/// So a keychain read that finds nothing asks this before it says so, and throws
/// ``ProtectedDataUnavailable`` instead when the answer is no. It is asked only then: an item
/// that was read is used as it is.
///
/// ``KeychainProtectedDataProbe`` is the default and needs nothing from UIKit. An app that wants
/// UIKit's answer passes its own:
///
/// ```swift
/// final class ApplicationProtectedData: ProtectedDataAvailability, @unchecked Sendable {
///     private let lock = NSLock()
///     private var available: Bool
///     private var observers: [NSObjectProtocol] = []
///
///     @MainActor init() {
///         available = UIApplication.shared.isProtectedDataAvailable
///         let center = NotificationCenter.default
///         observers = [
///             center.addObserver(forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: nil) { [weak self] _ in self?.set(true) },
///             center.addObserver(forName: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil, queue: nil) { [weak self] _ in self?.set(false) }
///         ]
///     }
///
///     var isAvailable: Bool { lock.withLock { available } }
///     private func set(_ value: Bool) { lock.withLock { available = value } }
/// }
/// ```
public protocol ProtectedDataAvailability: Sendable {
    /// Whether a keychain item the app wrote can be read now. `false` makes "not found"
    /// untrustworthy.
    var isAvailable: Bool { get }
}

/// The keychain could not be read because the device's protected data is not available yet —
/// before the first unlock, or while locked.
///
/// Not the same as having no session, and not a failure to report: nothing is opened, exchanged
/// or removed over it. Call `SessionAuthenticator.establishSession()` again once the data is
/// available — after `UIApplication.protectedDataDidBecomeAvailableNotification`, or when the
/// scene becomes active.
public struct ProtectedDataUnavailable: Error, Equatable, Sendable {
    /// The status the keychain returned: `errSecInteractionNotAllowed`, or `errSecItemNotFound`
    /// when ``ProtectedDataAvailability`` said the answer could not be trusted.
    public let status: OSStatus

    public init(status: OSStatus) {
        self.status = status
    }
}

/// Answers ``ProtectedDataAvailability`` by writing a small item that only an unlocked device
/// can write, and removing it again.
///
/// The probe item is `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, stricter than the
/// after-first-unlock items it vouches for: a locked device is never taken at its word that an
/// item is missing. firebase-ios-sdk settled on the same check (`isKeychainAccessible()`,
/// firebase-ios-sdk#16505). Needs no UIKit, so it works in app extensions and from any thread.
///
/// The keychain answers `errSecInteractionNotAllowed` to the write while protected data is not
/// available. Any other answer — success, or a keychain the process has no entitlement to, as in
/// a test run on macOS — counts as available, so "not found" means what it says there.
public struct KeychainProtectedDataProbe: ProtectedDataAvailability {
    private let service: String
    private let account: String

    /// Creates a probe.
    ///
    /// - Parameter service: The keychain service the probe item is written under. The item is
    ///   removed straight after, so the default suits every app.
    public init(service: String = "Authentication.ProtectedDataProbe") {
        self.service = service
        self.account = "probe"
    }

    public var isAvailable: Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // Deleting needs no key material, so a probe left behind by a crash cannot answer for
        // the write below with errSecDuplicateItem.
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data([0])
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        if status == errSecSuccess {
            SecItemDelete(query as CFDictionary)
        }
        return status != errSecInteractionNotAllowed
    }
}
