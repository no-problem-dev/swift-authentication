import Foundation

/// 認証状態
///
/// Firebase認証とバックエンドAPI認証の状態を表します。
/// 認証状態のみを管理し、ユーザー情報は別ドメインで管理します。
public enum AuthenticationState: Sendable, Equatable {
    /// 認証チェック中
    case checking

    /// 未認証
    ///
    /// ログイン画面を表示する必要があります。
    case unauthenticated

    /// Firebase認証済み（バックエンドAPI認証待ち）
    ///
    /// Firebase認証は完了していますが、バックエンドAPI認証が未完了の状態です。
    case firebaseAuthenticatedOnly

    /// 認証完了
    ///
    /// Firebase認証とバックエンドAPI認証の両方が完了しています。
    case authenticated

    /// 認証エラー
    case error(Error)

    /// 認証完了状態かどうか
    public var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }

    // Equatable conformance
    public static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.checking, .checking):
            return true
        case (.unauthenticated, .unauthenticated):
            return true
        case (.firebaseAuthenticatedOnly, .firebaseAuthenticatedOnly):
            return true
        case (.authenticated, .authenticated):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}
