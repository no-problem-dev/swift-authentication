import Foundation

/// The exchange layer: trades a credential for a session with the authentication server.
///
/// There is deliberately no per-provider method. Everything goes through one
/// ``signIn(with:)`` that takes an ``AuthCredential``, which is what keeps the core free of
/// provider SDKs. `AuthenticationSession` supplies the conformance that ships here,
/// `SessionAuthenticator`, which talks to a session server on the app's own domain.
public protocol Authenticator: Sendable {
    /// Returns the user of the stored session, or `nil` when there is none.
    ///
    /// Reads persisted state only: it presents no UI, starts no session and makes no request.
    func currentUser() async -> AuthUser?

    /// Trades a credential for a session and returns the user it belongs to.
    ///
    /// Conformances persist the session, so the next launch finds it through ``currentUser()``.
    func signIn(with credential: AuthCredential) async throws -> AuthUser

    /// Attaches a credential to the signed-in account, keeping its user id.
    ///
    /// The way to upgrade an anonymous account: everything stored under its id stays reachable,
    /// where ``signIn(with:)`` would replace the account with another and strand that data.
    ///
    /// Linking does not start a new session, so ``authStateChanges()`` need not emit; the
    /// returned user carries the updated ``AuthUser/isAnonymous`` and ``AuthUser/providerIDs``.
    ///
    /// - Parameter credential: A provider credential. ``AuthCredential/anonymous`` has nothing
    ///   to link.
    /// - Returns: The same user, now linked to the credential's provider.
    /// - Throws: ``AuthError/notAuthenticated`` when nobody is signed in,
    ///   ``AuthError/credentialAlreadyInUse(_:)`` when another account already owns the
    ///   credential, and ``AuthError/linkFailed(_:)`` for anything else. In every case the
    ///   current session is left as it was.
    func link(with credential: AuthCredential) async throws -> AuthUser

    /// Signs in to the account that owns a credential which failed to link.
    ///
    /// Switches the session to that account, so the user id changes.
    ///
    /// - Parameter collision: The payload of ``AuthError/credentialAlreadyInUse(_:)`` that this
    ///   authenticator raised.
    /// - Returns: The user of the owning account.
    /// - Throws: ``AuthError/credentialAlreadyInUse(_:)`` again, unchanged, when the collided
    ///   ``CredentialCollision/credential`` cannot be used a second time — it expired, or the
    ///   server spends it on first use. The caller then needs a fresh credential from the
    ///   provider, which is what ``AuthenticationStore/signIn(resolving:)`` does. Otherwise the
    ///   server's error.
    func signIn(resolving collision: CredentialCollision) async throws -> AuthUser

    /// Ends the session and clears the credentials stored for it.
    func signOut() async throws

    /// Deletes the account itself, not just the local session. Irreversible.
    ///
    /// Conformances end the local session once the account is gone, so ``authStateChanges()``
    /// emits `nil`. The session is cleared only after the deletion succeeded, so a failed
    /// request can be retried with the same session.
    ///
    /// - Parameter appleAuthorizationCode: A fresh authorization code from Sign in with Apple,
    ///   for the server to revoke the person's Apple tokens with, as App Review requires when
    ///   an account that used Sign in with Apple is deleted (guideline 5.1.1(v)). `nil` when
    ///   the account is not linked to Apple, or the code could not be obtained.
    func deleteAccount(appleAuthorizationCode: String?) async throws

    /// A stream of the signed-in user, emitting `nil` on sign-out.
    ///
    /// Conformances must emit the current value as soon as the stream is iterated.
    /// ``AuthenticationStore`` leaves its initial checking state on that first emission, so a
    /// stream that stays silent until something changes will hold the app on its launch
    /// screen forever.
    func authStateChanges() -> AsyncStream<AuthUser?>
}
