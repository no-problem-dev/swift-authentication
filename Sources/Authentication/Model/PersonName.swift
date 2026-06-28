import Foundation

/// 認証プロバイダから取得した氏名。
///
/// `PersonNameComponents` を vendor 非依存な値として保持する軽量型。
/// Sign in with Apple では初回認証時のみ取得可能。
public struct PersonName: Hashable, Sendable {
    /// 名（ファーストネーム）。
    public let givenName: String?
    /// 姓（ファミリーネーム）。
    public let familyName: String?

    public init(givenName: String? = nil, familyName: String? = nil) {
        self.givenName = givenName
        self.familyName = familyName
    }

    /// `PersonNameComponents` から生成する。値が無い場合は `nil` を返す。
    public init?(components: PersonNameComponents?) {
        guard let components else { return nil }
        guard components.givenName != nil || components.familyName != nil else { return nil }
        self.givenName = components.givenName
        self.familyName = components.familyName
    }
}
