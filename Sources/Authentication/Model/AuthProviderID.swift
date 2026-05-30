import Foundation

/// 認証プロバイダの識別子。
///
/// 特定のベンダー（Firebase など）に依存しない汎用的な識別子です。
/// 閉じた `enum` ではなく `RawRepresentable` な構造体にすることで、
/// パッケージを変更せずに独自プロバイダを追加できます。
///
/// ```swift
/// let custom = AuthProviderID(rawValue: "oidc.acme")
/// ```
public struct AuthProviderID: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Sign in with Apple。
    public static let apple = AuthProviderID(rawValue: "apple.com")

    /// Google Sign-In。
    public static let google = AuthProviderID(rawValue: "google.com")

    /// 匿名認証。
    public static let anonymous = AuthProviderID(rawValue: "anonymous")
}

extension AuthProviderID: CustomStringConvertible {
    public var description: String { rawValue }
}
