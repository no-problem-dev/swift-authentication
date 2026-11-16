import Foundation
import Authentication

/// Access tokens for the signed-in user, refreshed at `/v1/auth/refresh` before they expire.
///
/// Get one from ``SessionAuthenticator/tokenProvider``; it shares the authenticator's session,
/// so a sign-out is seen at once.
///
/// - A token with less than five minutes left is replaced before it is returned.
/// - Requests that need a refresh at the same time wait for one refresh.
/// - When the server rejects the refresh token (401), the session is removed from the device,
///   ``SessionAuthenticator/authStateChanges()`` emits `nil`, and the call throws
///   ``AuthError/notAuthenticated``. ``SessionAuthenticator/establishSession()`` then starts a
///   new session.
public struct SessionTokenProvider: AuthTokenProviding {
    let deviceSession: DeviceSession

    /// Returns an access token for the signed-in user.
    ///
    /// - Parameter forceRefresh: `true` refreshes even when the stored token has not expired —
    ///   what to do once after the API answered 401.
    /// - Returns: The token, or `nil` when nobody is signed in.
    /// - Throws: ``AuthError/notAuthenticated`` when the server rejected the refresh token, and
    ///   ``SessionServerError`` when a refresh that had to happen could not reach the server.
    ///   A refresh that was only due early falls back to the stored token while it still works.
    public func token(forceRefresh: Bool) async throws -> String? {
        try await deviceSession.validSession(forceRefresh: forceRefresh)?.accessToken
    }
}
