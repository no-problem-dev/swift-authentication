import Foundation

/// Work that has to finish after sign-in before the user may enter the app.
///
/// Usually provisioning: creating the user's record in your backend, seeding defaults,
/// claiming an invitation. `AuthenticationAPI` ships one conformance that posts to a REST
/// endpoint; anything else plugs in the same way.
///
/// - Important: ``AuthenticationStore`` calls ``perform(for:)`` once per user per session,
///   but retries and relaunches mean the server sees it more than once. The work on the
///   server side has to be idempotent.
public protocol PostAuthenticationAction: Sendable {
    /// Runs the post-sign-in work for a user.
    ///
    /// - Parameter user: The user whose session was just established.
    /// - Throws: Anything the work raised. ``AuthenticationStore`` publishes an `AuthError`
    ///   unchanged and wraps anything else in ``AuthError/postAuthenticationFailed(_:)``, so
    ///   throwing ``AuthError/sessionExpired(_:)`` or ``AuthError/notPermitted(_:)`` is how an
    ///   action says which remedy applies. Either way the session stays signed in, so a
    ///   failure here strands the user between states until a later attempt succeeds.
    func perform(for user: AuthUser) async throws
}

/// A post-authentication action that does nothing.
///
/// The store's default, for apps with no provisioning step.
public struct NoPostAuthentication: PostAuthenticationAction {
    public init() {}
    public func perform(for user: AuthUser) async throws {}
}

/// Runs several post-authentication actions in order, stopping at the first that throws.
///
/// Earlier actions are not undone when a later one fails, so order them from least to most
/// disposable.
public struct CompositePostAuthentication: PostAuthenticationAction {
    private let actions: [any PostAuthenticationAction]

    public init(_ actions: [any PostAuthenticationAction]) {
        self.actions = actions
    }

    public func perform(for user: AuthUser) async throws {
        for action in actions {
            try await action.perform(for: user)
        }
    }
}
