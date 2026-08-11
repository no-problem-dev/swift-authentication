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
    /// The credential was exchanged, but the post-authentication work has not finished.
    ///
    /// Keep showing a loading state: the session exists, yet the account may not be usable
    /// until provisioning completes.
    case authenticatedPendingProvisioning
    /// Fully signed in — exchanged and provisioned. The only state that should show app content.
    case authenticated(AuthUser)
    /// The exchange or the post-authentication work failed.
    ///
    /// Not necessarily terminal: a failed provisioning is retried on the next auth-state
    /// change, and the underlying session may still be live. The retry is unconditional, so
    /// an ``AuthError/notPermitted(_:)`` comes back on every subsequent change until
    /// something on the server side alters the answer.
    case error(any Error)

    /// Whether the session is fully usable.
    ///
    /// Stays `false` while post-authentication work is pending, so it is safe to gate app
    /// content on.
    public var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }

    /// The signed-in user, or `nil` in every other state — including while provisioning runs.
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
