import Foundation

/// 認証サーバへ渡す資格情報。
///
/// プロバイダ固有の SDK 型（Firebase の `AuthCredential` など）に依存しない
/// 中立な値型。`CredentialProvider` が生成し、`Authenticator` が
/// 認証サーバとのセッション交換に使用する。
///
/// 生成は各プロバイダ用ターゲットの便宜ファクトリ（例: `AuthCredential.apple(...)`）
/// を使うことを想定。
public struct AuthCredential: Sendable, Equatable {
    /// この資格情報が属するプロバイダ。
    public let provider: AuthProviderID

    /// OIDC ID トークン（Apple / Google）。匿名認証では `nil`。
    public let idToken: String?

    /// アクセストークン（Google が供給）。Apple では `nil`。
    public let accessToken: String?

    /// リプレイ攻撃対策の生 nonce（Apple フロー）。Google では `nil`。
    public let rawNonce: String?

    /// 氏名（Apple 初回認証時のみ）。
    public let fullName: PersonName?

    public init(
        provider: AuthProviderID,
        idToken: String? = nil,
        accessToken: String? = nil,
        rawNonce: String? = nil,
        fullName: PersonName? = nil
    ) {
        self.provider = provider
        self.idToken = idToken
        self.accessToken = accessToken
        self.rawNonce = rawNonce
        self.fullName = fullName
    }

    /// 匿名認証用の資格情報。
    public static let anonymous = AuthCredential(provider: .anonymous)
}
