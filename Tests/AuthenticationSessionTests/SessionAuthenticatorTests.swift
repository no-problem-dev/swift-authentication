import Testing
import Foundation
import Authentication
@testable import AuthenticationSession

/// A legacy session the test controls: it hands out a token, can fail, and records discards.
final class FakeLegacySource: LegacySessionSource, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?
    private var failure: (any Error)?
    private var discards = 0

    init(token: String?, failure: (any Error)? = nil) {
        self.token = token
        self.failure = failure
    }

    var discardCount: Int { lock.withLock { discards } }

    func setFailure(_ failure: (any Error)?) {
        lock.withLock { self.failure = failure }
    }

    func legacyIDToken() async throws -> String? {
        try lock.withLock {
            if let failure { throw failure }
            return token
        }
    }

    func discardLegacySession() async throws {
        lock.withLock {
            discards += 1
            token = nil
        }
    }
}

/// The flows in the order an app meets them: start anonymous, refresh, link, collide, migrate
/// from a legacy session, sign out and delete — against ``FakeWorker`` over a real URLSession.
@Suite("SessionAuthenticator")
struct SessionAuthenticatorTests {

    private func make(
        _ worker: FakeWorker,
        store: InMemorySessionStore = InMemorySessionStore(),
        legacySource: (any LegacySessionSource)? = nil
    ) -> SessionAuthenticator {
        SessionAuthenticator(
            baseURL: worker.baseURL,
            installID: { "install-1" },
            store: store,
            legacySource: legacySource,
            accountDeletionPath: "v1/account",
            urlSession: worker.urlSession
        )
    }

    private let apple = AuthCredential(provider: .apple, idToken: "apple-sub-1", rawNonce: "nonce")

    // MARK: - Anonymous

    @Test("a device with no session starts an anonymous one, and keeps it in the store")
    func startsAnonymous() async throws {
        let worker = FakeWorker()
        let store = InMemorySessionStore()
        let authenticator = make(worker, store: store)

        let user = try await authenticator.signIn(with: .anonymous)

        #expect(user.isAnonymous)
        #expect(user.providerIDs.isEmpty, "`anonymous` in linkedProviders is not a provider")
        #expect(worker.paths == ["POST /v1/auth/anonymous"])
        #expect(worker.recorded.first?.body["installId"] == "install-1")
        #expect(try store.load()?.user.id == user.id)
        #expect(await authenticator.currentUser() == user)
    }

    @Test("a stored session is used without a request, and a second establish opens nothing")
    func storedSessionIsReused() async throws {
        let worker = FakeWorker()
        let authenticator = make(worker)
        let first = try await authenticator.establishSession()

        let second = try await authenticator.establishSession()

        #expect(first == second)
        #expect(worker.paths == ["POST /v1/auth/anonymous"])
    }

    @Test("two callers at launch share one anonymous account")
    func concurrentEstablishOpensOne() async throws {
        let worker = FakeWorker()
        let authenticator = make(worker)

        async let a = authenticator.establishSession()
        async let b = authenticator.establishSession()
        let (first, second) = try await (a, b)

        #expect(first.id == second.id)
        #expect(worker.paths.filter { $0 == "POST /v1/auth/anonymous" }.count == 1)
    }

    // MARK: - Refresh

    @Test("a token with less than five minutes left is refreshed before it is handed out")
    func refreshesNearExpiry() async throws {
        let worker = FakeWorker()
        worker.update { $0.accessTokenLifetime = 60 }
        let store = InMemorySessionStore()
        let authenticator = make(worker, store: store)
        try await authenticator.establishSession()
        let refreshToken = try #require(try store.load()?.refreshToken)

        let token = try await authenticator.tokenProvider.token()

        #expect(worker.paths.last == "POST /v1/auth/refresh")
        #expect(worker.recorded.last?.body["refreshToken"] == refreshToken)
        #expect(token != "access-1")
        #expect(try store.load()?.refreshToken == refreshToken, "the server keeps the refresh token")
    }

    @Test("a token with time left is handed out as it is")
    func validTokenIsNotRefreshed() async throws {
        let worker = FakeWorker()
        let authenticator = make(worker)
        try await authenticator.establishSession()

        let token = try await authenticator.tokenProvider.token()

        #expect(token == "access-1")
        #expect(worker.paths == ["POST /v1/auth/anonymous"])
    }

    /// What an API client does after a 401: one forced refresh, then the request again.
    @Test("forceRefresh replaces a token that has not expired, once")
    func forceRefreshAfter401() async throws {
        let worker = FakeWorker()
        let authenticator = make(worker)
        try await authenticator.establishSession()
        let rejected = try await authenticator.tokenProvider.requiredToken()

        let renewed = try await authenticator.tokenProvider.requiredToken(forceRefresh: true)

        #expect(renewed != rejected)
        #expect(worker.paths == ["POST /v1/auth/anonymous", "POST /v1/auth/refresh"])
    }

    @Test("refreshes requested at the same time wait for one refresh")
    func concurrentRefreshesCoalesce() async throws {
        let worker = FakeWorker()
        worker.update { $0.refreshDelay = 0.1 }
        let authenticator = make(worker)
        try await authenticator.establishSession()
        let provider = authenticator.tokenProvider

        let tokens = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<5 {
                group.addTask { try await provider.requiredToken(forceRefresh: true) }
            }
            return try await group.reduce(into: Set<String>()) { $0.insert($1) }
        }

        #expect(tokens.count == 1)
        #expect(worker.paths.filter { $0 == "POST /v1/auth/refresh" }.count == 1)
    }

    @Test("a rejected refresh token removes the session, reports nil and throws notAuthenticated")
    func revokedRefreshTokenSignsOut() async throws {
        let worker = FakeWorker()
        let store = InMemorySessionStore()
        let authenticator = make(worker, store: store)
        try await authenticator.establishSession()
        let refreshToken = try #require(try store.load()?.refreshToken)
        worker.update { $0.revokedRefreshTokens = [refreshToken] }
        var states = authenticator.authStateChanges().makeAsyncIterator()
        #expect(await states.next() != nil)

        await #expect {
            _ = try await authenticator.tokenProvider.token(forceRefresh: true)
        } throws: { ($0 as? AuthError)?.code == .notAuthenticated }

        #expect(try store.load() == nil)
        #expect(await states.next() == .some(nil))
        #expect(await authenticator.currentUser() == nil)
    }

    @Test("an early refresh that cannot reach the server falls back to the token that still works")
    func earlyRefreshOfflineKeepsToken() async throws {
        let worker = FakeWorker()
        worker.update { $0.accessTokenLifetime = 60 }
        let authenticator = make(worker)
        try await authenticator.establishSession()
        worker.update { $0.unreachablePaths = ["/v1/auth/refresh"] }

        #expect(try await authenticator.tokenProvider.token() == "access-1")
        await #expect(throws: SessionServerError.self) {
            _ = try await authenticator.tokenProvider.token(forceRefresh: true)
        }
        #expect(await authenticator.currentUser() != nil, "an unreachable server is not a sign-out")
    }

    // MARK: - Linking and collisions

    @Test("linking Apple keeps the user id and sends the current token")
    func linkKeepsUserID() async throws {
        let worker = FakeWorker()
        let authenticator = make(worker)
        let anonymous = try await authenticator.establishSession()

        let linked = try await authenticator.link(with: apple)

        #expect(linked.id == anonymous.id)
        #expect(!linked.isAnonymous)
        #expect(linked.providerIDs == [.apple])
        let request = try #require(worker.recorded.last)
        #expect(request.path == "/v1/auth/apple")
        #expect(request.authorization == "Bearer access-1")
        #expect(request.body["identityToken"] == "apple-sub-1")
        #expect(await authenticator.currentUser() == linked)
    }

    @Test("a 409 is a collision carrying the credential, and resolving it switches to the owner")
    func collisionThenResolve() async throws {
        let worker = FakeWorker()
        worker.seedAccount(userID: "owner-1", subject: "apple:apple-sub-1", provider: "apple")
        let authenticator = make(worker)
        let anonymous = try await authenticator.establishSession()

        var collision: CredentialCollision?
        do {
            _ = try await authenticator.link(with: apple)
            Issue.record("expected a collision")
        } catch let AuthError.credentialAlreadyInUse(payload) {
            collision = payload
        }
        let payload = try #require(collision)
        #expect(payload.credential == apple)
        #expect(await authenticator.currentUser() == anonymous, "a collision leaves the session alone")

        let owner = try await authenticator.signIn(resolving: payload)

        #expect(owner.id == "owner-1")
        let resolving = try #require(worker.recorded.last { $0.path == "/v1/auth/apple" })
        #expect(resolving.authorization == nil, "resolving signs in; it does not link")
        #expect(resolving.body["mode"] == "sign_in_existing")
        #expect(worker.paths.last == "POST /v1/auth/sign-out", "the previous user's device is revoked")
        #expect(worker.recorded.last?.authorization == "Bearer access-1")
        #expect(await authenticator.currentUser()?.id == "owner-1")
    }

    @Test("unlinking removes the provider and keeps the user id and the tokens")
    func unlinkKeepsUserID() async throws {
        let worker = FakeWorker()
        let store = InMemorySessionStore()
        let authenticator = make(worker, store: store)
        let anonymous = try await authenticator.establishSession()
        _ = try await authenticator.link(with: apple)
        let tokenBefore = try store.load()?.accessToken

        let user = try await authenticator.unlink(.apple)

        #expect(user.id == anonymous.id)
        #expect(user.isAnonymous)
        #expect(worker.paths.last == "DELETE /v1/auth/identities/apple")
        #expect(try store.load()?.accessToken == tokenBefore)
        #expect(await authenticator.currentUser() == user)
    }

    // MARK: - Existing accounts

    @Test("signInExisting switches to the owning account without linking")
    func signInExistingFound() async throws {
        let worker = FakeWorker()
        worker.seedAccount(userID: "owner-1", subject: "apple:apple-sub-1", provider: "apple")
        let authenticator = make(worker)
        try await authenticator.establishSession()

        let user = try await authenticator.signInExisting(with: apple)

        #expect(user?.id == "owner-1")
        let request = try #require(worker.recorded.last { $0.path == "/v1/auth/apple" })
        #expect(request.body["mode"] == "sign_in_existing")
        #expect(request.authorization == nil)
    }

    @Test("signInExisting for a credential nobody uses returns nil and touches nothing")
    func signInExistingNotFound() async throws {
        let worker = FakeWorker()
        let store = InMemorySessionStore()
        let authenticator = make(worker, store: store)
        let anonymous = try await authenticator.establishSession()
        let before = try store.load()

        let user = try await authenticator.signInExisting(with: apple)

        #expect(user == nil)
        #expect(try store.load() == before)
        #expect(await authenticator.currentUser() == anonymous)
        #expect(!worker.paths.contains("POST /v1/auth/sign-out"))
    }

    @Test("findExisting holds the switch until commit")
    func findExistingThenCommit() async throws {
        let worker = FakeWorker()
        worker.seedAccount(userID: "owner-1", subject: "apple:apple-sub-1", provider: "apple")
        let store = InMemorySessionStore()
        let authenticator = make(worker, store: store)
        let anonymous = try await authenticator.establishSession()
        let before = try store.load()

        let pending = try #require(try await authenticator.findExisting(with: apple))

        #expect(pending.user.id == "owner-1")
        #expect(try store.load() == before)
        #expect(await authenticator.currentUser() == anonymous)
        #expect(!worker.paths.contains("POST /v1/auth/sign-out"))

        let user = try await pending.commit()

        #expect(user.id == "owner-1")
        #expect(await authenticator.currentUser()?.id == "owner-1")
        let signOut = try #require(worker.recorded.last { $0.path == "/v1/auth/sign-out" })
        #expect(signOut.authorization == "Bearer \(before?.accessToken ?? "")")
    }

    @Test("cancelling a found switch keeps the session and revokes the found one")
    func findExistingThenCancel() async throws {
        let worker = FakeWorker()
        worker.seedAccount(userID: "owner-1", subject: "apple:apple-sub-1", provider: "apple")
        let store = InMemorySessionStore()
        let authenticator = make(worker, store: store)
        let anonymous = try await authenticator.establishSession()
        let before = try store.load()

        let pending = try #require(try await authenticator.findExisting(with: apple))
        await pending.cancel()

        #expect(try store.load() == before)
        #expect(await authenticator.currentUser() == anonymous)
        let signOut = try #require(worker.recorded.last { $0.path == "/v1/auth/sign-out" })
        #expect(signOut.authorization == "Bearer \(pending.session.accessToken)")
    }

    @Test("findExisting for a credential nobody uses returns nil and touches nothing")
    func findExistingNotFound() async throws {
        let worker = FakeWorker()
        let store = InMemorySessionStore()
        let authenticator = make(worker, store: store)
        try await authenticator.establishSession()
        let before = try store.load()

        #expect(try await authenticator.findExisting(with: apple) == nil)
        #expect(try store.load() == before)
        #expect(!worker.paths.contains("POST /v1/auth/sign-out"))
    }

    @Test("a deleted account is reported as accountDeleted")
    func deletedAccountIsNamed() async throws {
        let worker = FakeWorker()
        worker.seedAccount(userID: "gone-1", subject: "apple:apple-sub-1", provider: "apple")
        worker.update { $0.deletedUserIDs = ["gone-1"] }
        let authenticator = make(worker)
        try await authenticator.establishSession()

        await #expect {
            _ = try await authenticator.signInExisting(with: apple)
        } throws: { ($0 as? AuthError)?.code == .accountDeleted }
    }

    @Test("linking with nobody signed in throws notAuthenticated without a request")
    func linkSignedOut() async {
        let worker = FakeWorker()
        let authenticator = make(worker)

        await #expect {
            _ = try await authenticator.link(with: apple)
        } throws: { ($0 as? AuthError)?.code == .notAuthenticated }
        #expect(worker.paths.isEmpty)
    }

    // MARK: - Legacy sessions

    @Test("a legacy session is exchanged, keeps its user id, and is forgotten afterwards")
    func legacySessionIsExchanged() async throws {
        let worker = FakeWorker()
        let legacy = FakeLegacySource(token: "firebase-token-legacy-uid")
        let authenticator = make(worker, legacySource: legacy)

        let user = try await authenticator.establishSession()

        #expect(user.id == "legacy-uid")
        #expect(worker.paths == ["POST /v1/auth/firebase"])
        #expect(worker.recorded.first?.body["idToken"] == "firebase-token-legacy-uid")
        #expect(legacy.discardCount == 1)
    }

    @Test("a failed legacy exchange opens no anonymous account, and a later attempt succeeds")
    func failedLegacyExchangeDoesNotGoAnonymous() async throws {
        let worker = FakeWorker()
        worker.update { $0.failLegacyExchange = true }
        let legacy = FakeLegacySource(token: "firebase-token-legacy-uid")
        let store = InMemorySessionStore()
        let authenticator = make(worker, store: store, legacySource: legacy)

        await #expect {
            _ = try await authenticator.establishSession()
        } throws: { ($0 as? AuthError)?.code == .sessionExchangeFailed }
        #expect(!worker.paths.contains("POST /v1/auth/anonymous"))
        #expect(try store.load() == nil)
        #expect(legacy.discardCount == 0)

        worker.update { $0.failLegacyExchange = false }
        let user = try await authenticator.establishSession()

        #expect(user.id == "legacy-uid")
        #expect(!worker.paths.contains("POST /v1/auth/anonymous"))
    }

    @Test("a legacy session of a deleted account is forgotten and a new anonymous one opened")
    func deletedLegacyAccountGoesAnonymous() async throws {
        let worker = FakeWorker()
        worker.update { $0.deletedUserIDs = ["legacy-uid"] }
        let legacy = FakeLegacySource(token: "firebase-token-legacy-uid")
        let authenticator = make(worker, legacySource: legacy)

        let user = try await authenticator.establishSession()

        #expect(user.id != "legacy-uid")
        #expect(worker.paths == ["POST /v1/auth/firebase", "POST /v1/auth/anonymous"])
        #expect(legacy.discardCount == 1)
    }

    @Test("a legacy source that cannot produce its token opens no anonymous account either")
    func legacySourceFailureDoesNotGoAnonymous() async throws {
        let worker = FakeWorker()
        let legacy = FakeLegacySource(token: "firebase-token-legacy-uid", failure: URLError(.notConnectedToInternet))
        let authenticator = make(worker, legacySource: legacy)

        await #expect {
            _ = try await authenticator.signIn(with: .anonymous)
        } throws: { ($0 as? AuthError)?.code == .sessionExchangeFailed }
        #expect(worker.paths.isEmpty)
    }

    // MARK: - Sign-out and deletion

    @Test("signing out revokes the device, clears the store, reports nil and forgets the legacy session")
    func signOut() async throws {
        let worker = FakeWorker()
        let legacy = FakeLegacySource(token: "firebase-token-legacy-uid")
        let store = InMemorySessionStore()
        let authenticator = make(worker, store: store, legacySource: legacy)
        try await authenticator.establishSession()
        var states = authenticator.authStateChanges().makeAsyncIterator()
        #expect(await states.next() != nil)

        try await authenticator.signOut()

        #expect(worker.recorded.last?.path == "/v1/auth/sign-out")
        #expect(worker.recorded.last?.authorization == "Bearer access-1")
        #expect(try store.load() == nil)
        #expect(await states.next() == .some(nil))

        let next = try await authenticator.establishSession()
        #expect(next.id != "legacy-uid", "starting again does not exchange the old session back")
        #expect(worker.paths.last == "POST /v1/auth/anonymous")
    }

    @Test("signing out works when the server cannot be reached")
    func signOutOffline() async throws {
        let worker = FakeWorker()
        let store = InMemorySessionStore()
        let authenticator = make(worker, store: store)
        try await authenticator.establishSession()
        worker.update { $0.unreachablePaths = ["/v1/auth/sign-out"] }

        try await authenticator.signOut()

        #expect(try store.load() == nil)
    }

    @Test("deleting sends the Apple code to the app's endpoint, then forgets the session")
    func deleteAccount() async throws {
        let worker = FakeWorker()
        let store = InMemorySessionStore()
        let authenticator = make(worker, store: store)
        try await authenticator.establishSession()
        _ = try await authenticator.link(with: apple)

        try await authenticator.deleteAccount(appleAuthorizationCode: "apple-code")

        let request = try #require(worker.recorded.last)
        #expect(request.method == "DELETE")
        #expect(request.path == "/v1/account")
        #expect(request.body == ["appleAuthorizationCode": "apple-code"])
        #expect(request.authorization?.hasPrefix("Bearer ") == true)
        #expect(try store.load() == nil)
    }

    @Test("a failed deletion keeps the session for a retry")
    func failedDeletionKeepsSession() async throws {
        let worker = FakeWorker()
        let store = InMemorySessionStore()
        let authenticator = make(worker, store: store)
        try await authenticator.establishSession()
        worker.update { $0.unreachablePaths = ["/v1/account"] }

        await #expect(throws: SessionServerError.self) {
            try await authenticator.deleteAccount(appleAuthorizationCode: nil)
        }
        #expect(try store.load() != nil)
    }

    // MARK: - Stream

    @Test("the stream starts with the current user")
    func streamStartsWithCurrentUser() async throws {
        let worker = FakeWorker()
        let authenticator = make(worker)
        let user = try await authenticator.establishSession()

        var states = authenticator.authStateChanges().makeAsyncIterator()

        #expect(await states.next() == .some(user))
    }
}

@Suite("AuthSession")
struct AuthSessionTests {
    @Test("decodes the server's shape, with times in epoch milliseconds")
    func decodesWire() throws {
        let json = #"""
        {"user":{"id":"u1","linkedProviders":["apple"],"createdAt":1763251200000},
         "accessToken":"a","accessTokenExpiresAt":1763337600000,"refreshToken":"d.s"}
        """#
        let session = try JSONDecoder().decode(AuthSession.self, from: Data(json.utf8))

        #expect(session.user.authUser == AuthUser(id: "u1", isAnonymous: false, providerIDs: [.apple]))
        #expect(session.accessTokenExpiresAt == Date(timeIntervalSince1970: 1_763_337_600))
        #expect(session.user.createdAt == Date(timeIntervalSince1970: 1_763_251_200))
    }

    @Test("survives a round trip through the store's encoding")
    func roundTrips() throws {
        let session = AuthSession(
            user: .init(id: "u1", linkedProviders: [.anonymous], createdAt: Date(timeIntervalSince1970: 1_763_251_200)),
            accessToken: "a",
            accessTokenExpiresAt: Date(timeIntervalSince1970: 1_763_337_600),
            refreshToken: "d.s"
        )

        let decoded = try JSONDecoder().decode(AuthSession.self, from: JSONEncoder().encode(session))

        #expect(decoded == session)
        #expect(decoded.user.authUser.isAnonymous)
    }
}
