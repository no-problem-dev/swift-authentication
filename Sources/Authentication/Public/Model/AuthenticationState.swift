import Foundation

/// 認証状態
public enum AuthenticationState: Sendable, Equatable {
    case checking
    case unauthenticated
    case firebaseAuthenticatedOnly
    case authenticated
    case error(Error)

    public var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }

    public static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.checking, .checking),
             (.unauthenticated, .unauthenticated),
             (.firebaseAuthenticatedOnly, .firebaseAuthenticatedOnly),
             (.authenticated, .authenticated),
             (.error, .error):
            return true
        default:
            return false
        }
    }
}
