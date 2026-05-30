import Foundation

/// 認証フローで発生するエラー。
///
/// 原因となった vendor 固有のエラーは関連値として保持しますが、型自体は
/// vendor 非依存です。`any Error` を含むため `Equatable` ではなく、
/// テストでの分類判定には `code` を使用します。
public enum AuthError: Error {
    /// ユーザーによるキャンセル（資格情報取得の中断など）。
    case cancelled
    /// 対応する `CredentialProvider` が登録されていないプロバイダが指定された。
    case unsupportedProvider(AuthProviderID)
    /// 資格情報の取得（Apple/Google の UI フロー等）に失敗。
    case credentialAcquisitionFailed(any Error)
    /// 認証サーバとのセッション交換に失敗。
    case sessionExchangeFailed(any Error)
    /// ログイン後処理（プロビジョニング）に失敗。
    case postAuthenticationFailed(any Error)
    /// サインアウトに失敗。
    case signOutFailed(any Error)
    /// アカウント削除に失敗。
    case deleteAccountFailed(any Error)
    /// 認証されていない状態で要求された操作。
    case notAuthenticated
    /// 設定不備（必要な値が未設定など）。
    case configuration(String)
}

extension AuthError {
    /// 関連値を含まない、テスト assertion 用の分類コード。
    public enum Code: Equatable, Sendable {
        case cancelled
        case unsupportedProvider
        case credentialAcquisitionFailed
        case sessionExchangeFailed
        case postAuthenticationFailed
        case signOutFailed
        case deleteAccountFailed
        case notAuthenticated
        case configuration
    }

    public var code: Code {
        switch self {
        case .cancelled: .cancelled
        case .unsupportedProvider: .unsupportedProvider
        case .credentialAcquisitionFailed: .credentialAcquisitionFailed
        case .sessionExchangeFailed: .sessionExchangeFailed
        case .postAuthenticationFailed: .postAuthenticationFailed
        case .signOutFailed: .signOutFailed
        case .deleteAccountFailed: .deleteAccountFailed
        case .notAuthenticated: .notAuthenticated
        case .configuration: .configuration
        }
    }
}
