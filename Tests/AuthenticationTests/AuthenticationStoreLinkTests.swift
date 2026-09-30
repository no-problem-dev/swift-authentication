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

/// Covers upgrading an anonymous account and what happens when the credential already
/// belongs to another account.
@MainActor
@Suite("AuthenticationStore – link and collision")
struct AuthenticationStoreLinkTests {

    private let anonymous = AuthUser(id: "anon-1", isAnonymous: true)
    private let linked = AuthUser(id: "anon-1", isAnonymous: false, providerIDs: [.apple])
    private let existing = AuthUser(id: "existing-9", providerIDs: [.apple])

    /// A store already signed in as the anonymous user.
    private func signedInStore(
        _ authenticator: MockAuthenticator,
        providers: [any CredentialProvider] = []
    ) async -> AuthenticationStore {
        let store = AuthenticationStore(authenticator: authenticator, credentialProviders: providers)
        authenticator.emit(anonymous)
        await waitUntil { store.state.isAuthenticated }
        return store
    }

    // MARK: - Link

    @Test("link(using:) acquires a credential and links it, keeping the user id")
    func linkUsingProvider() async throws {
        let authenticator = MockAuthenticator(stubbedUser: anonymous)
        authenticator.linkedUser = linked
        let credential = AuthCredential(provider: .apple, idToken: "id", rawNonce: "nonce")
        let provider = MockCredentialProvider(providerID: .apple, result: .success(credential))
        let store = await signedInStore(authenticator, providers: [provider])

        try await store.link(using: .apple)

        #expect(provider.acquireCallCount == 1)
        #expect(authenticator.linkedCredentials == [credential])
        #expect(authenticator.signInCallCount == 0, "linking must not replace the session")
        #expect(store.state == .authenticated(linked), "the upgraded user is republished")
    }

    @Test("link(using:) for an unregistered provider throws .unsupportedProvider")
    func linkUnsupportedProvider() async {
        let authenticator = MockAuthenticator(stubbedUser: anonymous)
        let store = await signedInStore(authenticator)

        await #expect {
            try await store.link(using: .google)
        } throws: { ($0 as? AuthError)?.code == .unsupportedProvider }
        #expect(authenticator.linkedCredentials.isEmpty)
    }

    @Test("a collision surfaces as .credentialAlreadyInUse and leaves the session alone")
    func linkCollision() async {
        let authenticator = MockAuthenticator(stubbedUser: anonymous)
        authenticator.linkError = AuthError.credentialAlreadyInUse(
            CredentialCollision(provider: .apple, email: "a@example.com")
        )
        let store = await signedInStore(authenticator)

        do {
            try await store.link(with: AuthCredential(provider: .apple, idToken: "id", rawNonce: "n"))
            Issue.record("expected a collision")
        } catch let AuthError.credentialAlreadyInUse(collision) {
            #expect(collision.provider == .apple)
            #expect(collision.email == "a@example.com")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
        #expect(store.state == .authenticated(anonymous))
    }

    @Test("a non-AuthError from the authenticator is wrapped as .linkFailed")
    func linkOtherFailure() async {
        let authenticator = MockAuthenticator(stubbedUser: anonymous)
        authenticator.linkError = TestError("network")
        let store = await signedInStore(authenticator)

        await #expect {
            try await store.link(with: AuthCredential(provider: .google, idToken: "i", accessToken: "a"))
        } throws: { ($0 as? AuthError)?.code == .linkFailed }
        #expect(store.state == .authenticated(anonymous), "a failed link is not a session error")
    }

    // MARK: - Resolving a collision

    @Test("signIn(resolving:) uses the replacement credential and acquires nothing")
    func resolveWithRenewal() async throws {
        let authenticator = MockAuthenticator(stubbedUser: anonymous)
        authenticator.resolvedUser = existing
        let provider = MockCredentialProvider(providerID: .apple)
        let store = await signedInStore(authenticator, providers: [provider])

        try await store.signIn(resolving: CredentialCollision(provider: .apple, renewedCredential: "renewed"))
        await waitUntil { store.state.user == existing }

        #expect(authenticator.resolveCallCount == 1)
        #expect(provider.acquireCallCount == 0)
        #expect(authenticator.signInCallCount == 0)
        #expect(store.state == .authenticated(existing))
    }

    /// The Apple case: the nonce inside the collided token is spent, so the only way in is a
    /// new authorization. Exchanging the collided credential again is what must never happen.
    @Test("without a usable replacement, a fresh credential is acquired — the collided one is never reused")
    func resolveAcquiresFreshCredential() async throws {
        let collided = AuthCredential(provider: .apple, idToken: "spent", rawNonce: "spent-nonce")
        let fresh = AuthCredential(provider: .apple, idToken: "fresh", rawNonce: "fresh-nonce")
        let authenticator = MockAuthenticator(stubbedUser: existing)
        authenticator.linkError = AuthError.credentialAlreadyInUse(CredentialCollision(provider: .apple))
        let provider = MockCredentialProvider(providerID: .apple, result: .success(fresh))
        let store = await signedInStore(authenticator, providers: [provider])

        var collision: CredentialCollision?
        do {
            try await store.link(with: collided)
        } catch let AuthError.credentialAlreadyInUse(payload) {
            collision = payload
        }
        try await store.signIn(resolving: #require(collision))
        await waitUntil { store.state.user == existing }

        #expect(authenticator.resolveCallCount == 1)
        #expect(provider.acquireCallCount == 1)
        #expect(authenticator.signedInCredentials == [fresh])
        #expect(!authenticator.signedInCredentials.contains(collided))
    }

    @Test("a fresh credential needs a registered provider")
    func resolveWithoutProvider() async {
        let authenticator = MockAuthenticator(stubbedUser: anonymous)
        let store = await signedInStore(authenticator)

        await #expect {
            try await store.signIn(resolving: CredentialCollision(provider: .google))
        } throws: { ($0 as? AuthError)?.code == .unsupportedProvider }
    }

    @Test("backing out of the provider's sheet while resolving propagates .cancelled")
    func resolveCancelled() async {
        let authenticator = MockAuthenticator(stubbedUser: anonymous)
        let provider = MockCredentialProvider(providerID: .apple, result: .failure(AuthError.cancelled))
        let store = await signedInStore(authenticator, providers: [provider])

        await #expect {
            try await store.signIn(resolving: CredentialCollision(provider: .apple))
        } throws: { ($0 as? AuthError)?.code == .cancelled }
        #expect(authenticator.signInCallCount == 0)
        #expect(store.state == .authenticated(anonymous))
    }

    @Test("a failed exchange while resolving throws .sessionExchangeFailed and keeps the current session")
    func resolveExchangeFails() async {
        let authenticator = MockAuthenticator(stubbedUser: anonymous)
        authenticator.resolveError = TestError("rejected")
        let store = await signedInStore(authenticator)

        await #expect {
            try await store.signIn(resolving: CredentialCollision(provider: .apple, renewedCredential: "r"))
        } throws: { ($0 as? AuthError)?.code == .sessionExchangeFailed }
        #expect(store.state == .authenticated(anonymous))
    }

    @Test("AuthError.code covers the collision and link cases")
    func codesForNewCases() {
        #expect(AuthError.credentialAlreadyInUse(CredentialCollision(provider: .apple)).code == .credentialAlreadyInUse)
        #expect(AuthError.linkFailed(TestError()).code == .linkFailed)
    }
}

@Suite("AuthTokenProviding")
struct AuthTokenProvidingTests {

    @Test("token() asks for the stored token, not a refresh")
    func tokenShorthandDoesNotRefresh() async throws {
        let provider = MockTokenProvider(cached: "cached", refreshed: "refreshed")

        #expect(try await provider.token() == "cached")
        #expect(provider.requests == [false])
    }

    @Test("tokenSource passes forceRefresh through", arguments: [
        (false, "cached"), (true, "refreshed")
    ])
    func tokenSourcePassesFreshness(forceRefresh: Bool, expected: String) async throws {
        let provider = MockTokenProvider(cached: "cached", refreshed: "refreshed")
        let source = provider.tokenSource

        #expect(try await source(forceRefresh) == expected)
        #expect(provider.requests == [forceRefresh])
    }

    @Test("requiredToken turns a signed-out nil into .notAuthenticated instead of an empty header")
    func requiredTokenThrowsWhenSignedOut() async {
        let provider = MockTokenProvider(cached: nil, refreshed: nil)

        await #expect {
            _ = try await provider.tokenSource(true)
        } throws: { ($0 as? AuthError)?.code == .notAuthenticated }
    }
}
