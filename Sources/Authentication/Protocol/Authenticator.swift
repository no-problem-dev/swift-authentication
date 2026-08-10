import Foundation

/// The exchange layer: trades a credential for a session with the authentication server.
///
/// There is deliberately no per-provider method. Everything goes through one
/// ``signIn(with:)`` that takes an ``AuthCredential``, which is what keeps the core free of
/// provider SDKs. `AuthenticationFirebase` supplies the conformance that ships here.
public protocol Authenticator: Sendable {
    /// Returns the user of the stored session, or `nil` when there is none.
    ///
    /// Reads persisted state only: it presents no UI and starts no session.
    func currentUser() async -> AuthUser?

    /// Trades a credential for a session and returns the user it belongs to.
    ///
    /// Conformances persist the session, so the next launch finds it through ``currentUser()``.
    func signIn(with credential: AuthCredential) async throws -> AuthUser

    /// Ends the session and clears the credentials stored for it.
    ///
    /// Tokens already handed out stay valid until they expire; a backend that needs immediate
    /// lockout has to revoke them itself.
    func signOut() async throws

    /// Deletes the account itself, not just the local session. Irreversible.
    ///
    /// Providers commonly require a recent sign-in and refuse otherwise, which arrives here as
    /// a thrown error.
    func deleteAccount() async throws

    /// A stream of the signed-in user, emitting `nil` on sign-out.
    ///
    /// Conformances must emit the current value as soon as the stream is iterated, the way
    /// Firebase's state-change listener does. ``AuthenticationStore`` leaves its initial
    /// checking state on that first emission, so a stream that stays silent until something
    /// changes will hold the app on its launch screen forever.
    func authStateChanges() -> AsyncStream<AuthUser?>
}
