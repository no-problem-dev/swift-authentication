import Foundation
@preconcurrency import FirebaseAuth
import Authentication

/// Exchanges credentials for a session using Firebase Authentication.
///
/// Converts the neutral `AuthCredential` into Firebase's own credential type and trades it
/// for a session. Firebase stores that session in the keychain, which outlives the process and
/// even the app's deletion — see `FirebaseConfigurator` for why that matters on reinstall.
public final class FirebaseAuthenticator: Authenticator, @unchecked Sendable {
    private let auth: Auth

    /// Creates an authenticator.
    ///
    /// - Parameter auth: The Firebase authentication instance to use. Defaults to the shared
    ///   one; pass another only to substitute it in tests.
    public init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    /// Returns the user restored from the keychain-backed session, or `nil` when there is
    /// none. Reads local state only — no network call, no token refresh.
    public func currentUser() async -> AuthUser? {
        auth.currentUser.map(FirebaseUserMapper.map)
    }

    /// Trades a credential for a Firebase session and returns the user it belongs to.
    ///
    /// An anonymous credential carries no tokens, so it opens an anonymous session instead of
    /// being exchanged.
    ///
    /// - Parameter credential: What the acquisition layer produced.
    /// - Returns: The signed-in user.
    /// - Throws: Firebase's authentication error, or a mapping error when the credential is
    ///   missing the fields its provider requires.
    public func signIn(with credential: Authentication.AuthCredential) async throws -> AuthUser {
        let result: AuthDataResult
        if let firebaseCredential = try FirebaseCredentialMapper.makeCredential(from: credential) {
            result = try await auth.signIn(with: firebaseCredential)
        } else {
            result = try await auth.signInAnonymously()
        }
        return FirebaseUserMapper.map(result.user)
    }

    /// Clears the keychain-backed session.
    ///
    /// Identity tokens already issued remain valid until they expire, so a backend that needs
    /// immediate lockout has to revoke them itself.
    ///
    /// - Throws: Firebase's sign-out error.
    public func signOut() async throws {
        try auth.signOut()
    }

    /// Deletes the Firebase account itself, not just the local session. Irreversible.
    ///
    /// - Throws: `AuthError.notAuthenticated` when no one is signed in. Firebase refuses
    ///   outright when the last sign-in is too old, and that refusal is thrown as-is — recover
    ///   by signing the user in again and retrying.
    public func deleteAccount() async throws {
        guard let user = auth.currentUser else {
            throw AuthError.notAuthenticated
        }
        try await user.delete()
    }

    /// A stream of the signed-in user, emitting `nil` while signed out.
    ///
    /// The current value arrives as soon as the stream is iterated, which is Firebase's
    /// listener behaviour and what `AuthenticationStore` relies on to leave its checking
    /// state. The listener is removed when iteration ends.
    public func authStateChanges() -> AsyncStream<AuthUser?> {
        // The listener belongs to the instance it was added to, which is not necessarily the
        // shared one — reaching for `Auth.auth()` here traps outright when no default app exists.
        nonisolated(unsafe) let auth = self.auth
        return AsyncStream { continuation in
            nonisolated(unsafe) let handle = auth.addStateDidChangeListener { _, user in
                continuation.yield(user.map(FirebaseUserMapper.map))
            }
            continuation.onTermination = { _ in
                auth.removeStateDidChangeListener(handle)
            }
        }
    }
}
