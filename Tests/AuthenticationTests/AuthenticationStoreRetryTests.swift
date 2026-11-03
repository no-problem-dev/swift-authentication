import Testing
import Foundation
@testable import Authentication

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: () -> Bool
) async {
    let deadline = ContinuousClock.now + timeout
    while !condition() && ContinuousClock.now < deadline {
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(2))
    }
}

private extension AuthenticationState {
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

/// A post-authentication action that holds each call until the test releases it, so a test
/// can act while an attempt is in flight.
private final class GatedPostAuthenticationAction: PostAuthenticationAction, @unchecked Sendable {
    private let lock = NSLock()
    private var _performCallCount = 0
    private var _performedUserIDs: [String] = []
    private var pending: [CheckedContinuation<Void, any Error>] = []

    var performCallCount: Int { lock.withLock { _performCallCount } }
    var performedUserIDs: [String] { lock.withLock { _performedUserIDs } }
    var waitingCount: Int { lock.withLock { pending.count } }

    func perform(for user: AuthUser) async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                _performCallCount += 1
                _performedUserIDs.append(user.id)
                pending.append(continuation)
            }
        }
    }

    /// Finishes the oldest waiting call, successfully or with `error`.
    func release(throwing error: (any Error)? = nil) {
        let continuation = lock.withLock { pending.isEmpty ? nil : pending.removeFirst() }
        if let error { continuation?.resume(throwing: error) } else { continuation?.resume() }
    }
}

@MainActor
@Suite("AuthenticationStore.retryPostAuthentication")
struct AuthenticationStoreRetryTests {

    @Test("a failed provisioning succeeds on retry, for the same user, without a new sign-in")
    func retryAfterFailureAuthenticates() async throws {
        let user = AuthUser(id: "retry", email: "r@example.com")
        let authenticator = MockAuthenticator(stubbedUser: user)
        let postAuth = MockPostAuthenticationAction(error: TestError("503"))
        let store = AuthenticationStore(authenticator: authenticator, postAuthentication: postAuth)

        authenticator.emit(user)
        await waitUntil { store.state.isError }
        #expect(store.state.isError)

        postAuth.error = nil
        await store.retryPostAuthentication()

        #expect(store.state == .authenticated(user))
        #expect(postAuth.performedUserIDs == ["retry", "retry"])
        #expect(authenticator.signInCallCount == 0)
        #expect(authenticator.signOutCallCount == 0)
    }

    @Test("a retry that fails again leaves the store in .error with the new failure")
    func retryThatFailsStaysInError() async throws {
        let user = AuthUser(id: "again")
        let authenticator = MockAuthenticator(stubbedUser: user)
        let postAuth = MockPostAuthenticationAction(error: TestError("first"))
        let store = AuthenticationStore(authenticator: authenticator, postAuthentication: postAuth)

        authenticator.emit(user)
        await waitUntil { store.state.isError }

        postAuth.error = AuthError.notPermitted(TestError("403"))
        await store.retryPostAuthentication()

        guard case .error(let error) = store.state else {
            Issue.record("expected .error, got \(store.state)")
            return
        }
        #expect((error as? AuthError)?.code == .notPermitted)
        #expect(postAuth.performCallCount == 2)

        // Still retryable after a second failure.
        postAuth.error = nil
        await store.retryPostAuthentication()
        #expect(store.state == .authenticated(user))
        #expect(postAuth.performCallCount == 3)
    }

    @Test("two retries in a row run the work once")
    func concurrentRetriesRunOnce() async throws {
        let user = AuthUser(id: "twice")
        let authenticator = MockAuthenticator(stubbedUser: user)
        let postAuth = GatedPostAuthenticationAction()
        let store = AuthenticationStore(authenticator: authenticator, postAuthentication: postAuth)

        authenticator.emit(user)
        await waitUntil { postAuth.waitingCount == 1 }
        postAuth.release(throwing: TestError("first"))
        await waitUntil { store.state.isError }

        let first = Task { await store.retryPostAuthentication() }
        await waitUntil { postAuth.waitingCount == 1 }
        #expect(store.state == .authenticatedPendingProvisioning)

        await store.retryPostAuthentication()   // Returns at once: an attempt is in flight.
        #expect(postAuth.performCallCount == 2)

        postAuth.release()
        await first.value
        #expect(store.state == .authenticated(user))
        #expect(postAuth.performCallCount == 2)
    }

    @Test("an emission for the same user during a retry neither reruns nor skips ahead")
    func emissionDuringRetryWaitsForIt() async throws {
        let user = AuthUser(id: "refresh")
        let authenticator = MockAuthenticator(stubbedUser: user)
        let postAuth = GatedPostAuthenticationAction()
        let store = AuthenticationStore(authenticator: authenticator, postAuthentication: postAuth)

        authenticator.emit(user)
        await waitUntil { postAuth.waitingCount == 1 }
        postAuth.release(throwing: TestError("first"))
        await waitUntil { store.state.isError }

        let retry = Task { await store.retryPostAuthentication() }
        await waitUntil { postAuth.waitingCount == 1 }

        // A token refresh reports the same user while the retry is still running.
        authenticator.emit(user)
        try await Task.sleep(for: .milliseconds(50))
        #expect(store.state == .authenticatedPendingProvisioning)
        #expect(postAuth.performCallCount == 2)

        postAuth.release()
        await retry.value
        #expect(store.state == .authenticated(user))
        #expect(postAuth.performCallCount == 2)
    }

    @Test("a sign-out while a retry runs wins, and the retry's outcome is dropped")
    func signOutDuringRetryWins() async throws {
        let user = AuthUser(id: "leave")
        let authenticator = MockAuthenticator(stubbedUser: user)
        let postAuth = GatedPostAuthenticationAction()
        let store = AuthenticationStore(authenticator: authenticator, postAuthentication: postAuth)

        authenticator.emit(user)
        await waitUntil { postAuth.waitingCount == 1 }
        postAuth.release(throwing: TestError("first"))
        await waitUntil { store.state.isError }

        let retry = Task { await store.retryPostAuthentication() }
        await waitUntil { postAuth.waitingCount == 1 }

        try await store.signOut()
        await waitUntil { store.state == .unauthenticated }

        postAuth.release()
        await retry.value
        #expect(store.state == .unauthenticated)

        // Nothing left to retry once signed out.
        await store.retryPostAuthentication()
        #expect(store.state == .unauthenticated)
        #expect(postAuth.performCallCount == 2)
    }

    @Test("after a failed provisioning and a sign-out, retry does nothing")
    func retryAfterSignOutDoesNothing() async throws {
        let user = AuthUser(id: "gone")
        let authenticator = MockAuthenticator(stubbedUser: user)
        let postAuth = MockPostAuthenticationAction(error: TestError("first"))
        let store = AuthenticationStore(authenticator: authenticator, postAuthentication: postAuth)

        authenticator.emit(user)
        await waitUntil { store.state.isError }

        try await store.signOut()
        await waitUntil { store.state == .unauthenticated }

        postAuth.error = nil
        await store.retryPostAuthentication()

        #expect(store.state == .unauthenticated)
        #expect(postAuth.performCallCount == 1)
    }

    @Test("after a failed exchange, retry does nothing")
    func retryAfterExchangeFailureDoesNothing() async {
        let authenticator = MockAuthenticator()
        authenticator.signInError = TestError("exchange")
        let postAuth = MockPostAuthenticationAction()
        let provider = MockCredentialProvider(providerID: .apple)
        let store = AuthenticationStore(
            authenticator: authenticator,
            postAuthentication: postAuth,
            credentialProviders: [provider]
        )

        await #expect(throws: AuthError.self) { try await store.signIn(using: .apple) }
        #expect(store.state.isError)

        await store.retryPostAuthentication()

        #expect(store.state.isError)
        #expect(postAuth.performCallCount == 0)
    }

    @Test("a failed exchange after a failed provisioning leaves nothing to retry")
    func exchangeFailureReplacesProvisioningFailure() async throws {
        let user = AuthUser(id: "mixed")
        let authenticator = MockAuthenticator(stubbedUser: user)
        let postAuth = MockPostAuthenticationAction(error: TestError("first"))
        let store = AuthenticationStore(authenticator: authenticator, postAuthentication: postAuth)

        authenticator.emit(user)
        await waitUntil { store.state.isError }

        authenticator.signInError = TestError("exchange")
        await #expect(throws: AuthError.self) { try await store.signIn(with: .anonymous) }

        postAuth.error = nil
        await store.retryPostAuthentication()

        guard case .error(let error) = store.state else {
            Issue.record("expected .error, got \(store.state)")
            return
        }
        #expect((error as? AuthError)?.code == .sessionExchangeFailed)
        #expect(postAuth.performCallCount == 1)
    }

    @Test("retry does nothing when already authenticated or still checking")
    func retryWithoutFailureDoesNothing() async {
        let user = AuthUser(id: "fine")
        let authenticator = MockAuthenticator(stubbedUser: user)
        let postAuth = MockPostAuthenticationAction()
        let store = AuthenticationStore(authenticator: authenticator, postAuthentication: postAuth)

        await store.retryPostAuthentication()
        #expect(store.state == .checking)

        authenticator.emit(user)
        await waitUntil { store.state.isAuthenticated }
        await store.retryPostAuthentication()

        #expect(store.state == .authenticated(user))
        #expect(postAuth.performCallCount == 1)
    }

    @Test("a re-emission after a failure still provisions again, as before")
    func emissionAfterFailureStillRetries() async {
        let user = AuthUser(id: "emit")
        let authenticator = MockAuthenticator(stubbedUser: user)
        let postAuth = MockPostAuthenticationAction(error: TestError("first"))
        let store = AuthenticationStore(authenticator: authenticator, postAuthentication: postAuth)

        authenticator.emit(user)
        await waitUntil { store.state.isError }

        postAuth.error = nil
        authenticator.emit(user)
        await waitUntil { store.state.isAuthenticated }

        #expect(store.state == .authenticated(user))
        #expect(postAuth.performCallCount == 2)
    }
}
