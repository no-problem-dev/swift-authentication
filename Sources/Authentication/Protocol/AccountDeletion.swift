import Foundation

/// Deletes the signed-in account somewhere other than the device — normally on the app's own
/// server, which removes its data and the authentication account in one request.
///
/// Why not from the device: deleting the authentication account there is refused when the
/// last sign-in is too old (Firebase's `requiresRecentLogin`). If the app first deletes its
/// data on the server and then asks the device to delete the account, that refusal arrives
/// after the data is already gone, and the person is told deletion failed when half of it
/// happened. One server request that deletes the data and then the account has neither
/// problem: it holds admin rights, and a failure at any point can be retried until it
/// converges.
///
/// Hand a conformance to the authenticator — `FirebaseAuthenticator(accountDeletion:)` — and
/// ``Authenticator/deleteAccount()`` calls it, then ends the local session. `AuthenticationAPI`
/// ships `APIAccountDeletion`, which sends the request through swift-api-client.
///
/// - Important: The authenticator signs out only after this returns. Signing out first would
///   throw away the bearer token a failed request needs to be retried.
public protocol AccountDeletion: Sendable {
    /// Deletes the account and everything that belongs to it.
    ///
    /// - Parameter user: The signed-in user. The request normally identifies the caller from
    ///   its bearer token rather than from this value.
    /// - Throws: Anything that prevented the deletion. The account must then still exist, or
    ///   exist in a state a retry finishes deleting.
    func deleteAccount(of user: AuthUser) async throws
}
