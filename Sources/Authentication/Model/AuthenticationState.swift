import Foundation

/// The stage a sign-in session has reached.
///
/// ``AuthenticationStore`` owns the value and views switch on it to decide what to show.
public enum AuthenticationState {
    /// The starting point, while a stored session is being restored.
    ///
    /// Not the same as being signed out — show a launch screen here, not the sign-in screen.
    case checking
    /// No session: none was stored, or the user signed out. The only state that should show
    /// the sign-in screen.
    case unauthenticated
    /// Signed in. The only state that should show app content.
    case authenticated(AuthUser)
    /// The exchange failed. The next auth-state change replaces it.
    case error(any Error)

    /// Whether someone is signed in.
    public var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }

    /// The signed-in user, or `nil` in every other state.
    public var user: AuthUser? {
        if case .authenticated(let user) = self { return user }
        return nil
    }
}

extension AuthenticationState: Equatable {
    public static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.checking, .checking),
             (.unauthenticated, .unauthenticated):
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
