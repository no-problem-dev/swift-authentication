import Foundation

/// 認証プロバイダから取得した氏名。
///
/// `PersonNameComponents` を vendor 非依存な値として保持するための軽量型です。
/// Sign in with Apple では初回認証時のみ取得できます。
public struct PersonName: Hashable, Sendable {
    public let givenName: String?
    public let familyName: String?

    public init(givenName: String? = nil, familyName: String? = nil) {
        self.givenName = givenName
        self.familyName = familyName
    }

    /// `PersonNameComponents` から生成します。値が無い場合は `nil` を返します。
    public init?(components: PersonNameComponents?) {
        guard let components else { return nil }
        guard components.givenName != nil || components.familyName != nil else { return nil }
        self.givenName = components.givenName
        self.familyName = components.familyName
    }
}
