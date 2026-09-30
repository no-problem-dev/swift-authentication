import Foundation
@preconcurrency import FirebaseAuth
import Authentication

/// Exchanges credentials for a session using Firebase Authentication.
///
/// Converts the neutral `AuthCredential` into Firebase's own credential type and trades it
/// for a session. Firebase stores that session in the keychain, which outlives the process and
/// even the app's deletion — see `FirebaseConfigurator` for why that matters on reinstall.
public final class FirebaseAuthenticator: Authenticator, Sendable {
    private let backend: any FirebaseAuthBackend
    private let accountDeletion: (any AccountDeletion)?

    /// Creates an authenticator.
    ///
    /// - Parameters:
    ///   - auth: The Firebase authentication instance to use. Defaults to the shared one; pass
    ///     another only to substitute it in tests.
    ///   - accountDeletion: Where ``deleteAccount()`` deletes the account. `nil`, the default,
    ///     deletes the Firebase account from the device, which Firebase refuses when the last
    ///     sign-in is too old and which leaves the app's own server data alone. An app with a
    ///     server passes its deletion endpoint here — `APIAccountDeletion` from
    ///     `AuthenticationAPI` — so the server deletes the data and the account in one request.
    public convenience init(auth: Auth = Auth.auth(), accountDeletion: (any AccountDeletion)? = nil) {
        self.init(backend: LiveFirebaseAuthBackend(auth: auth), accountDeletion: accountDeletion)
    }

    init(backend: any FirebaseAuthBackend, accountDeletion: (any AccountDeletion)? = nil) {
        self.backend = backend
        self.accountDeletion = accountDeletion
    }

    /// Returns the user restored from the keychain-backed session, or `nil` when there is
    /// none. Reads local state only — no network call, no token refresh.
    public func currentUser() async -> AuthUser? {
        backend.currentUser()
    }

    /// Trades a credential for a Firebase session and returns the user it belongs to.
    ///
    /// An anonymous credential carries no tokens, so it opens an anonymous session instead of
    /// being exchanged. Any other credential replaces the current session — an anonymous one
    /// included, whose user id and data are then left behind. Use ``link(with:)`` to keep them.
    ///
    /// - Parameter credential: What the acquisition layer produced.
    /// - Returns: The signed-in user.
    /// - Throws: Firebase's authentication error, or ``FirebaseAuthenticatorError`` when the
    ///   credential is missing the fields its provider requires.
    public func signIn(with credential: Authentication.AuthCredential) async throws -> AuthUser {
        if let firebaseCredential = try FirebaseCredentialMapper.makeCredential(from: credential) {
            return try await backend.signIn(with: firebaseCredential)
        }
        return try await backend.signInAnonymously()
    }

    /// Links a credential to the signed-in Firebase user, keeping its uid.
    ///
    /// - Parameter credential: An Apple or Google credential.
    /// - Returns: The same user, now linked to the credential's provider.
    /// - Throws: `AuthError.notAuthenticated` when nobody is signed in.
    ///   `AuthError.credentialAlreadyInUse` when another Firebase account already owns the
    ///   credential; its payload carries the replacement credential Firebase issued, which
    ///   ``signIn(resolving:)`` uses. `AuthError.linkFailed` for everything else, including a
    ///   credential that cannot be converted and a provider already linked to this user.
    public func link(with credential: Authentication.AuthCredential) async throws -> AuthUser {
        let firebaseCredential: FirebaseAuth.AuthCredential
        do {
            guard let converted = try FirebaseCredentialMapper.makeCredential(from: credential) else {
                throw FirebaseAuthenticatorError.invalidCredential(credential.provider)
            }
            firebaseCredential = converted
        } catch {
            throw AuthError.linkFailed(error)
        }

        let linked: AuthUser?
        do {
            linked = try await backend.linkCurrentUser(with: firebaseCredential)
        } catch let error as NSError
            where error.domain == AuthErrors.domain
            && error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
            throw AuthError.credentialAlreadyInUse(Self.collision(from: error, provider: credential.provider))
        } catch {
            throw AuthError.linkFailed(error)
        }
        guard let linked else { throw AuthError.notAuthenticated }
        return linked
    }

    /// Signs in to the Firebase account that owns a credential which failed to link, using the
    /// replacement credential Firebase issued with the rejection.
    ///
    /// The credential passed to ``link(with:)`` is never reused: Firebase has already consumed
    /// the nonce inside an Apple identity token, so a second exchange fails with "Duplicate
    /// credential received".
    ///
    /// - Parameter collision: The payload of the `AuthError.credentialAlreadyInUse` that
    ///   ``link(with:)`` threw.
    /// - Returns: The user of the owning account. The uid changes to that account's.
    /// - Throws: `AuthError.credentialAlreadyInUse(collision)` unchanged when Firebase issued no
    ///   replacement — a fresh credential from the provider is needed — and Firebase's error
    ///   when the exchange fails.
    public func signIn(resolving collision: CredentialCollision) async throws -> AuthUser {
        guard let renewed = collision.renewedCredential as? FirebaseRenewedCredential else {
            throw AuthError.credentialAlreadyInUse(collision)
        }
        return try await backend.signIn(with: renewed.credential)
    }

    /// Clears the keychain-backed session.
    ///
    /// Identity tokens already issued remain valid until they expire, so a backend that needs
    /// immediate lockout has to revoke them itself.
    ///
    /// - Throws: Firebase's sign-out error.
    public func signOut() async throws {
        try backend.signOut()
    }

    /// Deletes the account, then ends the local session. Irreversible.
    ///
    /// With an `accountDeletion` given at init, that does the deleting — normally the app's
    /// server, removing its data and the Firebase account in one request — and the session is
    /// cleared only after it succeeds, so a failed request can be retried with the same bearer
    /// token. Without one, the Firebase account is deleted from the device.
    ///
    /// - Throws: `AuthError.notAuthenticated` when no one is signed in; whatever the
    ///   `accountDeletion` threw, with the session untouched; on the device path, Firebase's
    ///   refusal when the last sign-in is too old (`requiresRecentLogin`), thrown as-is.
    ///   `AuthError.signOutFailed` when the account is gone but the local session could not be
    ///   cleared.
    public func deleteAccount() async throws {
        guard let user = backend.currentUser() else {
            throw AuthError.notAuthenticated
        }
        if let accountDeletion {
            try await accountDeletion.deleteAccount(of: user)
        } else {
            try await backend.deleteCurrentUser()
        }
        do {
            try backend.signOut()
        } catch {
            throw AuthError.signOutFailed(error)
        }
    }

    /// Revokes the signed-in user's Sign in with Apple tokens, as App Review requires when an
    /// account that used Sign in with Apple is deleted (guideline 5.1.1(v)).
    ///
    /// Call it **before** ``deleteAccount()``: Firebase authorizes the revocation with the
    /// current user's ID token, which no longer exists once the account is gone. Get the code
    /// from a fresh Apple authorization — `AppleCredentialProvider().acquireCredential()` and
    /// its `authorizationCode` — because Apple accepts each code once and only for about five
    /// minutes, so the one from the original sign-in is long spent.
    ///
    /// - Parameter authorizationCode: The authorization code from that Apple authorization.
    /// - Throws: `AuthError.notAuthenticated` when no one is signed in (Firebase would
    ///   otherwise never complete the request), or Firebase's error when the revocation fails.
    public func revokeAppleToken(authorizationCode: String) async throws {
        guard backend.currentUser() != nil else {
            throw AuthError.notAuthenticated
        }
        try await backend.revokeToken(authorizationCode: authorizationCode)
    }

    /// A stream of the signed-in user, emitting `nil` while signed out.
    ///
    /// The current value arrives as soon as the stream is iterated, which is Firebase's
    /// listener behaviour and what `AuthenticationStore` relies on to leave its checking
    /// state. The listener is removed when iteration ends.
    public func authStateChanges() -> AsyncStream<AuthUser?> {
        backend.stateChanges()
    }

    // MARK: - Internals

    private static func collision(from error: NSError, provider: Authentication.AuthProviderID) -> CredentialCollision {
        let renewed = error.userInfo[AuthErrors.userInfoUpdatedCredentialKey] as? FirebaseAuth.AuthCredential
        return CredentialCollision(
            provider: provider,
            email: error.userInfo[AuthErrors.userInfoEmailKey] as? String,
            renewedCredential: renewed.map(FirebaseRenewedCredential.init)
        )
    }
}
