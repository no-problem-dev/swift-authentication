import Foundation

/// An identifier for a sign-in provider, open to values this package has never heard of.
///
/// A `RawRepresentable` struct rather than a closed `enum` on purpose: adding your own
/// provider takes no change here. The raw values are the same strings an authentication
/// server reports, so an identifier survives the round trip into ``AuthUser/providerIDs``.
///
/// ```swift
/// let custom = AuthProviderID(rawValue: "oidc.acme")
/// ```
public struct AuthProviderID: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Sign in with Apple, under the identifier the authentication server reports for it.
    public static let apple = AuthProviderID(rawValue: "apple.com")

    /// Google Sign-In, under the identifier the authentication server reports for it.
    public static let google = AuthProviderID(rawValue: "google.com")

    /// A session with no provider behind it.
    ///
    /// Not an identifier any server issues: the exchange recognises this value and opens an
    /// anonymous session instead of trading a credential.
    public static let anonymous = AuthProviderID(rawValue: "anonymous")
}

extension AuthProviderID: CustomStringConvertible {
    public var description: String { rawValue }
}
