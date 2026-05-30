import Foundation

/// 認証状態。`AuthenticationStore` が保持し、View が観測して画面を切り替えます。
public enum AuthenticationState {
    /// 初期状態。認証状態を確認中。
    case checking
    /// 未認証。
    case unauthenticated
    /// 認証サーバでの交換は完了したが、ログイン後処理（プロビジョニング）が未完了。
    case authenticatedPendingProvisioning
    /// 完全に認証済み（交換 + プロビジョニング完了）。
    case authenticated(AuthUser)
    /// エラー。
    case error(any Error)

    public var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }

    /// 認証済みの場合のユーザー。
    public var user: AuthUser? {
        if case .authenticated(let user) = self { return user }
        return nil
    }
}

extension AuthenticationState: Equatable {
    public static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.checking, .checking),
             (.unauthenticated, .unauthenticated),
             (.authenticatedPendingProvisioning, .authenticatedPendingProvisioning):
            return true
        case let (.authenticated(lhsUser), .authenticated(rhsUser)):
            return lhsUser == rhsUser
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}
