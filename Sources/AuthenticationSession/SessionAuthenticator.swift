import Foundation
import Authentication

/// Signs in with sessions the app's own server issues — no third-party authentication service.
///
/// The server (`@studio/app-auth` in the app's Worker) issues the user id and the tokens. Apple
/// and Google only prove who the person is: their tokens are sent to the server, which verifies
/// them with the providers' public keys. Every request goes to `baseURL`, a domain the app owns,
/// which is what keeps sign-in working where Google's endpoints are unreachable.
///
/// The session lives in a ``SessionStore`` — the keychain unless you pass another — so
/// ``currentUser()`` answers without a request. ``tokenProvider`` hands out access tokens,
/// refreshing them before they expire.
///
/// ```swift
/// let authenticator = SessionAuthenticator(
///     baseURL: URL(string: "https://api.example.com")!,
///     installID: { InstallID.current }   // A UUID the app keeps in UserDefaults.
/// )
/// let store = AuthenticationStore(authenticator: authenticator, credentialProviders: [AppleCredentialProvider()])
/// let apiToken = authenticator.tokenProvider.tokenSource
/// ```
public final class SessionAuthenticator: Authenticator {
    let deviceSession: DeviceSession
    private let accountDeletionPath: String

    /// Creates an authenticator.
    ///
    /// - Parameters:
    ///   - baseURL: The app's API on a domain it owns. Not `workers.dev`, which some networks
    ///     cannot resolve.
    ///   - installID: An identifier for this installation, which the server records against the
    ///     device's refresh token. Asked for on every exchange.
    ///   - store: Where the session is kept. The keychain by default.
    ///   - legacySource: The session an earlier version of the app left on the device, for apps
    ///     moving off another authentication service. `nil` for an app that never had one.
    ///   - accountDeletionPath: The app's endpoint, relative to `baseURL`, that deletes the
    ///     signed-in account and everything it owns.
    ///   - urlSession: The session requests go through.
    ///   - requestTimeout: How long one request may take, in seconds. Long by default, for slow
    ///     and unstable connections.
    public init(
        baseURL: URL,
        installID: @escaping @Sendable () -> String,
        store: any SessionStore = KeychainSessionStore(),
        legacySource: (any LegacySessionSource)? = nil,
        accountDeletionPath: String = "v1/account",
        urlSession: URLSession = .shared,
        requestTimeout: TimeInterval = 20
    ) {
        self.deviceSession = DeviceSession(
            store: store,
            server: SessionServer(baseURL: baseURL, urlSession: urlSession, requestTimeout: requestTimeout),
            installID: installID,
            legacySource: legacySource
        )
        self.accountDeletionPath = accountDeletionPath
    }

    /// Access tokens for the signed-in user, for the app's API client.
    public var tokenProvider: SessionTokenProvider {
        SessionTokenProvider(deviceSession: deviceSession)
    }

    /// Makes sure the device has a session, and returns its user.
    ///
    /// Call it at launch, before the first request. In order:
    ///
    /// 1. A stored session is used as it is, refreshed first when its access token is close to
    ///    expiry. When the refresh cannot reach the server the stored session is still used.
    /// 2. With none stored, a `legacySource` that still holds an earlier session has it
    ///    exchanged at `/v1/auth/firebase`, keeping the person's user id.
    /// 3. Otherwise a new anonymous session is opened at `/v1/auth/anonymous`.
    ///
    /// Concurrent calls share one attempt, so two callers at launch never open two accounts.
    ///
    /// - Throws: ``AuthError/sessionExchangeFailed(_:)`` when step 2 fails. No anonymous session
    ///   is opened in its place — that would strand the person's records — so call this again
    ///   later, when the network is back. ``SessionServerError`` when step 3 fails, and
    ///   ``KeychainSessionStore/Failure`` when the stored session could not be read.
    @discardableResult
    public func establishSession() async throws -> AuthUser {
        try await deviceSession.establish().user.authUser
    }

    /// Returns the user of the stored session, without a request.
    public func currentUser() async -> AuthUser? {
        try? await deviceSession.current()?.user.authUser
    }

    /// Opens a session.
    ///
    /// ``AuthCredential/anonymous`` goes through ``establishSession()``: it returns the stored
    /// session's user when there is one, and exchanges a legacy session before it opens a new
    /// anonymous one. To start over as a new anonymous user, call ``signOut()`` first.
    ///
    /// An Apple or Google credential signs in as the account it belongs to — created on the
    /// server when there is none — and replaces the current session. Use ``link(with:)`` to
    /// keep the current user id.
    ///
    /// - Throws: ``SessionCredentialError/invalidCredential(_:)`` for a credential without an
    ///   ID token, ``AuthError/accountDeleted`` for a credential of a deleted account, and
    ///   ``SessionServerError`` when the server refused otherwise or could not be reached.
    public func signIn(with credential: AuthCredential) async throws -> AuthUser {
        if credential.provider == .anonymous {
            return try await establishSession()
        }
        return try await Self.namingDeletion {
            try await deviceSession.signIn(with: credential).user.authUser
        }
    }

    /// Signs in to the account an Apple or Google credential already belongs to, sending
    /// `mode: "sign_in_existing"`. When it belongs to none the server creates nothing, links
    /// nothing, and this returns `nil` with the current session untouched.
    ///
    /// Switching to another user revokes the previous session's device on the server.
    ///
    /// - Throws: As for ``signIn(with:)``.
    public func signInExisting(with credential: AuthCredential) async throws -> AuthUser? {
        try await Self.namingDeletion {
            try await deviceSession.signInExisting(with: credential)?.user.authUser
        }
    }

    /// Links an Apple or Google credential to the signed-in account, keeping its user id.
    ///
    /// - Throws: ``AuthError/notAuthenticated`` when nobody is signed in.
    ///   ``AuthError/credentialAlreadyInUse(_:)`` when the server answers 409 because another
    ///   account owns the credential; ``signIn(resolving:)`` switches to it with the same token.
    ///   ``AuthError/linkFailed(_:)`` for anything else.
    public func link(with credential: AuthCredential) async throws -> AuthUser {
        do {
            return try await deviceSession.link(credential).user.authUser
        } catch let error as AuthError {
            throw error
        } catch let error as SessionServerError where error.isAccountDeleted {
            throw AuthError.accountDeleted
        } catch let error as SessionServerError where error.status == 409 {
            throw AuthError.credentialAlreadyInUse(CredentialCollision(credential: credential))
        } catch {
            throw AuthError.linkFailed(error)
        }
    }

    /// Removes Apple or Google from the signed-in account at `DELETE /v1/auth/identities/:provider`,
    /// keeping the user id and the tokens.
    ///
    /// - Throws: ``AuthError/notAuthenticated`` when nobody is signed in, and
    ///   ``SessionServerError`` otherwise — a 404 `identity_not_linked` when the provider was not
    ///   linked.
    public func unlink(_ provider: AuthProviderID) async throws -> AuthUser {
        try await Self.namingDeletion {
            try await deviceSession.unlink(provider).user.authUser
        }
    }

    /// Signs in to the account that owns a credential which failed to link, with the same
    /// credential and `mode: "sign_in_existing"`. The server verifies the token by its
    /// signature, so a second use is accepted. The previous session's device is revoked.
    ///
    /// - Throws: ``AuthError/credentialAlreadyInUse(_:)`` unchanged when the server no longer
    ///   accepts the token (401) — it expired while the person decided — or no account owns it
    ///   any more, so the caller acquires a fresh one. Otherwise as for ``signIn(with:)``.
    public func signIn(resolving collision: CredentialCollision) async throws -> AuthUser {
        let owner: AuthUser?
        do {
            owner = try await signInExisting(with: collision.credential)
        } catch let error as SessionServerError where error.status == 401 {
            throw AuthError.credentialAlreadyInUse(collision)
        }
        guard let owner else { throw AuthError.credentialAlreadyInUse(collision) }
        return owner
    }

    /// Forgets the session on the device, then asks the server to revoke it.
    ///
    /// Works offline: the revocation is best effort, and the device no longer holds the refresh
    /// token either way. A `legacySource` is told to forget its session too, so the next
    /// ``establishSession()`` opens a new anonymous user instead of exchanging it back.
    ///
    /// - Throws: ``KeychainSessionStore/Failure`` when the stored session could not be removed.
    public func signOut() async throws {
        try await deviceSession.signOut()
    }

    /// Deletes the account through the app's endpoint, then forgets the session.
    ///
    /// Sends `DELETE <accountDeletionPath>` with the bearer token and a JSON body of
    /// `{ "appleAuthorizationCode": … }` (the key is left out when there is no code). The session
    /// is cleared only after the server succeeded, so a failure can be retried.
    ///
    /// - Throws: ``AuthError/notAuthenticated`` when nobody is signed in, and
    ///   ``SessionServerError`` when the server refused or could not be reached.
    public func deleteAccount(appleAuthorizationCode: String?) async throws {
        try await deviceSession.deleteAccount(path: accountDeletionPath, appleAuthorizationCode: appleAuthorizationCode)
    }

    /// A stream of the signed-in user: the current one first, then a value each time the user
    /// changes — `nil` on sign-out, on deletion, and when the server revoked the session.
    ///
    /// A refresh or a link keeps the user id and does not emit.
    public func authStateChanges() -> AsyncStream<AuthUser?> {
        let deviceSession = self.deviceSession
        return AsyncStream { continuation in
            let id = UUID()
            continuation.onTermination = { _ in
                Task { await deviceSession.stopObserving(id) }
            }
            Task { await deviceSession.observe(id, continuation) }
        }
    }

    /// Reports the server's 410 `account_deleted` as ``AuthError/accountDeleted``.
    private static func namingDeletion<T: Sendable>(_ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch let error as SessionServerError where error.isAccountDeleted {
            throw AuthError.accountDeleted
        }
    }
}
