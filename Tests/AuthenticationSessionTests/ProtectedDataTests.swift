import Testing
import Foundation
import Security
import Authentication
@testable import AuthenticationSession

/// Protected data the test locks and unlocks, counting how often it was asked.
final class FakeProtectedData: ProtectedDataAvailability, @unchecked Sendable {
    private let lock = NSLock()
    private var available: Bool
    private var asks = 0

    init(available: Bool) {
        self.available = available
    }

    var askCount: Int { lock.withLock { asks } }

    func set(available: Bool) {
        lock.withLock { self.available = available }
    }

    var isAvailable: Bool {
        lock.withLock {
            asks += 1
            return available
        }
    }
}

/// Prewarmed and background launches before the first unlock, or while locked: the keychain
/// cannot be read, and may answer "not found" for an item that is there.
@Suite("Protected data")
struct ProtectedDataTests {
    private func keychainStore(_ protectedData: FakeProtectedData) -> KeychainSessionStore {
        KeychainSessionStore(
            service: "AuthenticationSessionTests-\(UUID().uuidString)",
            account: "session",
            protectedData: protectedData
        )
    }

    private let session = AuthSession(
        user: .init(id: "u1", linkedProviders: [.apple], createdAt: Date(timeIntervalSince1970: 1_763_251_200)),
        accessToken: "a",
        accessTokenExpiresAt: Date(timeIntervalSince1970: (Date().timeIntervalSince1970 + 24 * 60 * 60).rounded()),
        refreshToken: "d.s"
    )

    // MARK: - KeychainSessionStore

    @Test("an item not found while protected data is unavailable is not reported as no session")
    func notFoundWhileLockedThrows() throws {
        let protectedData = FakeProtectedData(available: false)
        let store = keychainStore(protectedData)

        #expect(throws: ProtectedDataUnavailable(status: errSecItemNotFound)) { try store.load() }

        protectedData.set(available: true)
        #expect(try store.load() == nil)
    }

    @Test("an item that was read is used without asking about protected data")
    func readItemIsTrusted() throws {
        let protectedData = FakeProtectedData(available: false)
        let store = keychainStore(protectedData)
        defer { try? store.clear() }
        try store.save(session)

        #expect(try store.load() == session)
        #expect(protectedData.askCount == 0)
    }

    @Test("the keychain probe answers available on an unlocked machine and leaves nothing behind")
    func probeLeavesNoItem() {
        let service = "AuthenticationSessionTests-probe-\(UUID().uuidString)"
        let probe = KeychainProtectedDataProbe(service: service)

        #expect(probe.isAvailable)
        #expect(probe.isAvailable, "a second probe is not stopped by the first one's item")

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        #expect(SecItemCopyMatching(query as CFDictionary, nil) == errSecItemNotFound)
    }

    // MARK: - SessionAuthenticator

    @Test("a locked keychain opens no anonymous account, and the first launch after unlock does")
    func lockedKeychainWaitsForUnlock() async throws {
        let worker = FakeWorker()
        let protectedData = FakeProtectedData(available: false)
        let store = keychainStore(protectedData)
        defer { try? store.clear() }
        let authenticator = SessionAuthenticator(
            baseURL: worker.baseURL,
            installID: { "install-1" },
            store: store,
            urlSession: worker.urlSession
        )

        await #expect(throws: ProtectedDataUnavailable.self) { try await authenticator.establishSession() }
        await #expect(throws: ProtectedDataUnavailable.self, "nothing was cached as no session") {
            try await authenticator.establishSession()
        }
        #expect(await authenticator.currentUser() == nil)
        #expect(worker.paths.isEmpty)

        protectedData.set(available: true)
        let user = try await authenticator.establishSession()

        #expect(worker.paths == ["POST /v1/auth/anonymous"])
        #expect(try store.load()?.user.id == user.id)
    }

    @Test("a stored session behind a locked keychain is kept once unlocked, with no account opened")
    func storedSessionSurvivesLockedLaunch() async throws {
        let worker = FakeWorker()
        let store = LockableSessionStore(session)
        let authenticator = SessionAuthenticator(
            baseURL: worker.baseURL,
            installID: { "install-1" },
            store: store,
            urlSession: worker.urlSession
        )

        store.locked = true
        await #expect(throws: ProtectedDataUnavailable.self) { try await authenticator.establishSession() }

        store.locked = false
        let user = try await authenticator.establishSession()

        #expect(user.id == "u1")
        #expect(worker.paths.isEmpty)
    }

    @Test("observers told nobody while locked hear the stored user once a read after unlock finds it")
    func observersHearStoredUserAfterUnlock() async throws {
        let worker = FakeWorker()
        let store = LockableSessionStore(session)
        let authenticator = SessionAuthenticator(
            baseURL: worker.baseURL,
            installID: { "install-1" },
            store: store,
            urlSession: worker.urlSession
        )

        store.locked = true
        let heard = HeardUsers(authenticator.authStateChanges())
        await heard.waitFor { $0 == [nil] }
        await #expect(throws: ProtectedDataUnavailable.self) { try await authenticator.establishSession() }

        store.locked = false
        try await authenticator.establishSession()

        await heard.waitFor { $0.count == 2 }
        #expect(await heard.ids == [nil, "u1"])
        #expect(worker.paths.isEmpty)
    }

    @Test("an observer that arrives after the session was read hears it once")
    func lateObserverHearsUserOnce() async throws {
        let worker = FakeWorker()
        let authenticator = SessionAuthenticator(
            baseURL: worker.baseURL,
            installID: { "install-1" },
            store: LockableSessionStore(session),
            urlSession: worker.urlSession
        )
        var early = authenticator.authStateChanges().makeAsyncIterator()
        #expect(await early.next()??.id == "u1")

        try await authenticator.signOut()
        #expect(await early.next() == .some(nil), "the next value is the sign-out, not a repeat of u1")
    }

    @MainActor
    @Test("the store leaves signed-out for the stored user when establishSession succeeds after unlock")
    func storeFollowsUnlock() async throws {
        let worker = FakeWorker()
        let store = LockableSessionStore(session)
        store.locked = true
        let authenticator = SessionAuthenticator(
            baseURL: worker.baseURL,
            installID: { "install-1" },
            store: store,
            urlSession: worker.urlSession
        )
        let authentication = AuthenticationStore(authenticator: authenticator)
        await waitFor { authentication.state == .unauthenticated }

        await #expect(throws: ProtectedDataUnavailable.self) {
            try await authentication.signIn(with: .anonymous)
        }
        #expect(authentication.state == .unauthenticated, "not an error")

        store.locked = false
        try await authenticator.establishSession()
        await waitFor { authentication.state.isAuthenticated }

        #expect(authentication.state.user?.id == "u1")
        #expect(worker.paths.isEmpty)
    }

    @Test("a legacy session behind a locked keychain is neither exchanged nor replaced by an anonymous one")
    func lockedLegacySourceWaits() async throws {
        let worker = FakeWorker()
        let legacy = FakeLegacySource(token: "firebase-token-legacy-uid", failure: ProtectedDataUnavailable(status: errSecItemNotFound))
        let store = InMemorySessionStore()
        let authenticator = SessionAuthenticator(
            baseURL: worker.baseURL,
            installID: { "install-1" },
            store: store,
            legacySource: legacy,
            urlSession: worker.urlSession
        )

        await #expect(throws: ProtectedDataUnavailable.self, "reported as it is, not as a failed exchange") {
            try await authenticator.establishSession()
        }
        #expect(worker.paths.isEmpty)
        #expect(legacy.discardCount == 0)
        #expect(try store.load() == nil)

        legacy.setFailure(nil)
        let user = try await authenticator.establishSession()

        #expect(user.id == "legacy-uid")
        #expect(worker.paths == ["POST /v1/auth/firebase"])
    }

    @Test("a locked legacy source also keeps a device with anonymous sessions disabled waiting, not signed out")
    func lockedLegacySourceWithAnonymousDisabled() async throws {
        let worker = FakeWorker()
        let legacy = FakeLegacySource(token: "firebase-token-legacy-uid", failure: ProtectedDataUnavailable(status: errSecInteractionNotAllowed))
        let authenticator = SessionAuthenticator(
            baseURL: worker.baseURL,
            installID: { "install-1" },
            store: InMemorySessionStore(),
            legacySource: legacy,
            anonymous: .disabled,
            urlSession: worker.urlSession
        )

        await #expect(throws: ProtectedDataUnavailable.self) { try await authenticator.establishSession() }
        #expect(worker.paths.isEmpty)
    }
}

@MainActor
private func waitFor(timeout: Duration = .seconds(2), _ condition: () -> Bool) async {
    let deadline = ContinuousClock.now + timeout
    while !condition() && ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(2))
    }
}

/// Collects what a stream of users emits, so a value that never comes fails a wait instead of
/// hanging the test.
actor HeardUsers {
    private(set) var ids: [String?] = []

    init(_ stream: AsyncStream<AuthUser?>) {
        Task { await self.consume(stream) }
    }

    private func consume(_ stream: AsyncStream<AuthUser?>) async {
        for await user in stream { ids.append(user?.id) }
    }

    func waitFor(timeout: Duration = .seconds(2), _ condition: ([String?]) -> Bool) async {
        let deadline = ContinuousClock.now + timeout
        while !condition(ids) && ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(2))
        }
    }
}

/// A store whose session is there all along but cannot be read while `locked`.
final class LockableSessionStore: SessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var session: AuthSession?
    private var isLocked = false

    init(_ session: AuthSession?) {
        self.session = session
    }

    var locked: Bool {
        get { lock.withLock { isLocked } }
        set { lock.withLock { isLocked = newValue } }
    }

    func load() throws -> AuthSession? {
        try lock.withLock {
            if isLocked { throw ProtectedDataUnavailable(status: errSecInteractionNotAllowed) }
            return session
        }
    }

    func save(_ session: AuthSession) throws {
        try lock.withLock {
            if isLocked { throw ProtectedDataUnavailable(status: errSecInteractionNotAllowed) }
            self.session = session
        }
    }

    func clear() throws {
        lock.withLock { session = nil }
    }
}
