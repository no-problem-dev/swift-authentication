import Foundation
import Authentication

/// The device's one session, and every change made to it.
///
/// `SessionAuthenticator` and `SessionTokenProvider` share an instance, so a refresh, a
/// sign-out and a sign-in can never run over one another. The store is written through on every
/// change and also kept in memory, because a call that suspends between the two would let
/// another one read a session that is already gone.
actor DeviceSession {
    /// How close to expiry an access token is replaced before use. Wide, because a request can
    /// take seconds on a slow connection and the token must still be valid when it lands.
    static let refreshMargin: TimeInterval = 5 * 60

    private let store: any SessionStore
    private let server: SessionServer
    private let installID: @Sendable () -> String
    private let legacySource: (any LegacySessionSource)?

    private var cached: AuthSession?
    private var isLoaded = false
    /// Counts replacements, so a request that started before one can tell its answer is stale.
    private var generation = 0
    private var refreshing: Task<AuthSession, any Error>?
    private var establishing: Task<AuthSession, any Error>?
    private var observers: [UUID: AsyncStream<AuthUser?>.Continuation] = [:]

    init(
        store: any SessionStore,
        server: SessionServer,
        installID: @escaping @Sendable () -> String,
        legacySource: (any LegacySessionSource)?
    ) {
        self.store = store
        self.server = server
        self.installID = installID
        self.legacySource = legacySource
    }

    // MARK: - Reading

    func current() throws -> AuthSession? {
        if !isLoaded {
            cached = try store.load()
            isLoaded = true
        }
        return cached
    }

    /// The stored session with an access token good for at least ``refreshMargin``, refreshed
    /// first when it is not. `nil` when nobody is signed in.
    ///
    /// When a refresh that was not forced fails for any reason but a rejection, the stored
    /// token is returned while it has not expired yet: a slow network should not turn a token
    /// with four minutes left into a failure.
    func validSession(forceRefresh: Bool) async throws -> AuthSession? {
        guard let session = try current() else { return nil }
        let remaining = session.accessTokenExpiresAt.timeIntervalSinceNow
        if !forceRefresh, remaining > Self.refreshMargin { return session }
        do {
            return try await refreshed()
        } catch let error as AuthError {
            throw error
        } catch {
            guard !forceRefresh, remaining > 0 else { throw error }
            return session
        }
    }

    // MARK: - Establishing

    /// Returns the session to use from now on: the stored one, else one exchanged from the
    /// legacy source, else a new anonymous one. Concurrent calls share one attempt.
    func establish() async throws -> AuthSession {
        if let establishing { return try await establishing.value }
        let task = Task { try await self.performEstablish() }
        establishing = task
        defer { establishing = nil }
        return try await task.value
    }

    private func performEstablish() async throws -> AuthSession {
        if let stored = try current() {
            do {
                if let valid = try await validSession(forceRefresh: false) { return valid }
            } catch let error as AuthError where error.code == .notAuthenticated || error.code == .accountDeleted {
                // The server revoked the stored session; it is gone now. Start over below.
            } catch {
                // Unreachable: keep using what is stored, and refresh when a request needs it.
                return stored
            }
        }

        if let legacySource {
            let exchanged: AuthSession?
            do {
                exchanged = try await exchangeLegacySession(from: legacySource)
            } catch let error as SessionServerError where error.isAccountDeleted {
                // The person deleted that account. Nothing is left to keep, so start anew.
                try? await legacySource.discardLegacySession()
                exchanged = nil
            } catch {
                // Never fall back to a new anonymous user here: it would strand the person's
                // records under the legacy user id. The next attempt tries again.
                throw AuthError.sessionExchangeFailed(error)
            }
            if let exchanged { return exchanged }
        }

        let session = try await server.startAnonymous(installID: installID())
        try replace(with: session)
        return session
    }

    private func exchangeLegacySession(from source: any LegacySessionSource) async throws -> AuthSession? {
        guard let idToken = try await source.legacyIDToken() else { return nil }
        let session = try await server.exchangeLegacy(idToken: idToken, installID: installID())
        try replace(with: session)
        try? await source.discardLegacySession()
        return session
    }

    // MARK: - Changing

    /// Signs in with a provider's credential, replacing the current session.
    func signIn(with credential: AuthCredential) async throws -> AuthSession {
        let session = try await server.exchange(credential, mode: .linkOrSignIn, installID: installID(), bearer: nil)
        try await switchTo(session)
        return session
    }

    /// Signs in to the account a credential belongs to, or returns `nil` — touching nothing —
    /// when it belongs to none.
    func signInExisting(with credential: AuthCredential) async throws -> AuthSession? {
        let session: AuthSession
        do {
            session = try await server.exchange(credential, mode: .signInExisting, installID: installID(), bearer: nil)
        } catch let error as SessionServerError where error.status == 404 {
            return nil
        }
        try await switchTo(session)
        return session
    }

    /// Replaces the session, and when that changed the user, revokes the previous one's device
    /// on the server. Best effort: the switch has already happened either way.
    private func switchTo(_ session: AuthSession) async throws {
        let previous = try current()
        try replace(with: session)
        if let previous, previous.user.id != session.user.id {
            try? await server.signOut(bearer: previous.accessToken)
        }
    }

    /// Removes a provider from the signed-in account; the tokens stay as they are.
    func unlink(_ provider: AuthProviderID) async throws -> AuthSession {
        guard let valid = try await validSession(forceRefresh: false) else {
            throw AuthError.notAuthenticated
        }
        let startedAt = generation
        let user = try await server.unlink(provider, bearer: valid.accessToken)
        guard generation == startedAt, let latest = try current() else { throw AuthError.notAuthenticated }
        let session = AuthSession(
            user: user,
            accessToken: latest.accessToken,
            accessTokenExpiresAt: latest.accessTokenExpiresAt,
            refreshToken: latest.refreshToken
        )
        try replace(with: session)
        return session
    }

    /// Links a credential to the signed-in account.
    ///
    /// - Throws: ``AuthError/notAuthenticated`` when nobody is signed in, or nobody is any more
    ///   by the time the server answers. Otherwise the server's error, unchanged.
    func link(_ credential: AuthCredential) async throws -> AuthSession {
        guard let valid = try await validSession(forceRefresh: false) else {
            throw AuthError.notAuthenticated
        }
        let startedAt = generation
        let session = try await server.exchange(credential, mode: .linkOrSignIn, installID: installID(), bearer: valid.accessToken)
        guard generation == startedAt else { throw AuthError.notAuthenticated }
        try replace(with: session)
        return session
    }

    /// Clears the session on the device and asks the server to revoke it.
    ///
    /// The device forgets first and the server is told afterwards, best effort: signing out
    /// has to work offline, and a refresh token the device no longer holds cannot be used.
    func signOut() async throws {
        let accessToken = try current()?.accessToken
        try replace(with: nil)
        try? await legacySource?.discardLegacySession()
        if let accessToken {
            try? await server.signOut(bearer: accessToken)
        }
    }

    /// Deletes the account through the app's endpoint, then forgets the session.
    func deleteAccount(path: String, appleAuthorizationCode: String?) async throws {
        guard let valid = try await validSession(forceRefresh: false) else {
            throw AuthError.notAuthenticated
        }
        try await server.deleteAccount(path: path, bearer: valid.accessToken, appleAuthorizationCode: appleAuthorizationCode)
        try replace(with: nil)
        try? await legacySource?.discardLegacySession()
    }

    // MARK: - Refreshing

    private func refreshed() async throws -> AuthSession {
        if let refreshing { return try await refreshing.value }
        let task = Task { try await self.performRefresh() }
        refreshing = task
        defer { refreshing = nil }
        return try await task.value
    }

    private func performRefresh() async throws -> AuthSession {
        guard let session = try current() else { throw AuthError.notAuthenticated }
        let startedAt = generation
        let fresh: AuthSession
        do {
            fresh = try await server.refresh(refreshToken: session.refreshToken)
        } catch let error as SessionServerError where error.status == 401 || error.isAccountDeleted {
            if generation == startedAt { try replace(with: nil) }
            throw error.isAccountDeleted ? AuthError.accountDeleted : AuthError.notAuthenticated
        }
        guard generation == startedAt else {
            // Signed out or switched accounts while the refresh was in flight: that wins.
            guard let latest = try current() else { throw AuthError.notAuthenticated }
            return latest
        }
        try replace(with: fresh)
        return fresh
    }

    // MARK: - Writing and observing

    private func replace(with session: AuthSession?) throws {
        if let session {
            try store.save(session)
        } else {
            try store.clear()
        }
        let previousUserID = cached?.user.id
        cached = session
        isLoaded = true
        generation += 1
        if session?.user.id != previousUserID {
            broadcast(session?.user.authUser)
        }
    }

    func observe(_ id: UUID, _ continuation: AsyncStream<AuthUser?>.Continuation) {
        observers[id] = continuation
        continuation.yield((try? current())?.user.authUser)
    }

    func stopObserving(_ id: UUID) {
        observers[id] = nil
    }

    private func broadcast(_ user: AuthUser?) {
        for continuation in observers.values {
            continuation.yield(user)
        }
    }
}
