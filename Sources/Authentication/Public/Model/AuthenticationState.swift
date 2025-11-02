import Foundation
import GeneralDomain

/// 認証状態
///
/// Firebase認証とバックエンドAPI認証の状態を表します。
/// オンボーディングやプロフィール管理はアプリ側の責務として分離されています。
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
    case firebaseAuthenticatedOnly(User)

    /// 認証完了
    ///
    /// Firebase認証とバックエンドAPI認証の両方が完了しています。
    case authenticated(User)

    /// 認証エラー
    case error(Error)

    /// 認証完了状態かどうか
    public var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }

    /// 認証済みユーザー情報
    ///
    /// - Returns: ユーザー情報。未認証の場合はnil
    public var user: User? {
        switch self {
        case .authenticated(let user):
            return user
        case .firebaseAuthenticatedOnly(let user):
            return user
        default:
            return nil
        }
    }

    // Equatable conformance
    public static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.checking, .checking):
            return true
        case (.unauthenticated, .unauthenticated):
            return true
        case (.firebaseAuthenticatedOnly(let lUser), .firebaseAuthenticatedOnly(let rUser)):
            return lUser.id == rUser.id
        case (.authenticated(let lUser), .authenticated(let rUser)):
            return lUser.id == rUser.id
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}
