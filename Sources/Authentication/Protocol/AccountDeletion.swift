import Foundation

/// Deletes the signed-in account somewhere other than the device — normally on the app's own
/// server, which removes its data and the authentication account in one request.
///
/// `SessionAuthenticator` sends that request itself, to the path it is given. This protocol is
/// the seam for an ``Authenticator`` of another kind, which hands the deletion to whatever the
/// app plugs in and then ends the local session.
///
/// - Important: The authenticator signs out only after this returns. Signing out first would
///   throw away the bearer token a failed request needs to be retried.
public protocol AccountDeletion: Sendable {
    /// Deletes the account and everything that belongs to it.
    ///
    /// - Parameters:
    ///   - user: The signed-in user. The request normally identifies the caller from its
    ///     bearer token rather than from this value.
    ///   - appleAuthorizationCode: A fresh Sign in with Apple authorization code for the server
    ///     to revoke the person's Apple tokens with, or `nil` — see
    ///     ``Authenticator/deleteAccount(appleAuthorizationCode:)``.
    /// - Throws: Anything that prevented the deletion. The account must then still exist, or
    ///   exist in a state a retry finishes deleting.
    func deleteAccount(of user: AuthUser, appleAuthorizationCode: String?) async throws
}
