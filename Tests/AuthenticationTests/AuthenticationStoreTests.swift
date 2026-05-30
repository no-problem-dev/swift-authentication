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

@MainActor
@Suite("AuthenticationStore")
struct AuthenticationStoreTests {

    // MARK: - Happy path

    @Test("signIn(using:) acquires a credential, exchanges it, then provisions once")
    func signInUsingProviderFullFlow() async throws {
        let user = AuthUser(id: "abc", email: "a@example.com")
        let authenticator = MockAuthenticator(stubbedUser: user)
        let provider = MockCredentialProvider(providerID: .apple)
        let postAuth = MockPostAuthenticationAction()
        let store = AuthenticationStore(
            authenticator: authenticator,
            postAuthentication: postAuth,
            credentialProviders: [provider]
        )

        try await store.signIn(using: .apple)
        await waitUntil { store.state.isAuthenticated }

        #expect(provider.acquireCallCount == 1)
        #expect(authenticator.signInCallCount == 1)
        #expect(postAuth.performCallCount == 1)
        #expect(postAuth.performedUserIDs == ["abc"])
        #expect(store.state == .authenticated(user))
    }

    @Test("credential acquired by the provider is forwarded to the authenticator")
    func credentialForwarded() async throws {
        let credential = AuthCredential(provider: .google, idToken: "id", accessToken: "access")
        let authenticator = MockAuthenticator()
        let provider = MockCredentialProvider(providerID: .google, result: .success(credential))
        let store = AuthenticationStore(authenticator: authenticator, credentialProviders: [provider])

        try await store.signIn(using: .google)

        #expect(authenticator.signedInCredentials == [credential])
    }

    // MARK: - Idempotency

    @Test("provisioning runs only once even when auth state fires repeatedly")
    func provisioningIsIdempotentAcrossRepeatedEmissions() async throws {
        let user = AuthUser(id: "dup")
        let authenticator = MockAuthenticator(stubbedUser: user)
        let postAuth = MockPostAuthenticationAction()
        let store = AuthenticationStore(authenticator: authenticator, postAuthentication: postAuth)

        // Firebase の listener が同一ユーザーで複数回発火する状況を再現。
        authenticator.emit(user)
        authenticator.emit(user)
        authenticator.emit(user)
        await waitUntil { store.state.isAuthenticated }
        // さらに発火しても増えないこと。
        authenticator.emit(user)
        await waitUntil { postAuth.performCallCount > 1 }

        #expect(postAuth.performCallCount == 1)
        #expect(store.state == .authenticated(user))
    }

    @Test("signing out resets idempotency so the next sign-in provisions again")
    func provisioningResetsAfterSignOut() async throws {
        let user = AuthUser(id: "u")
        let authenticator = MockAuthenticator(stubbedUser: user)
        let postAuth = MockPostAuthenticationAction()
        let store = AuthenticationStore(authenticator: authenticator, postAuthentication: postAuth)

        authenticator.emit(user)
        await waitUntil { store.state.isAuthenticated }
        #expect(postAuth.performCallCount == 1)

        try await store.signOut()
        await waitUntil { store.state == .unauthenticated }
        #expect(store.state == .unauthenticated)

        authenticator.emit(user)
        await waitUntil { postAuth.performCallCount == 2 }
        #expect(postAuth.performCallCount == 2)
        #expect(store.state == .authenticated(user))   // store を最後まで生存させる
    }

    // MARK: - State transitions

    @Test("starts in .checking and becomes .unauthenticated on a nil emission")
    func nilEmissionUnauthenticates() async throws {
        let authenticator = MockAuthenticator()
        let store = AuthenticationStore(authenticator: authenticator)
        #expect(store.state == .checking)

        authenticator.emit(nil)
        await waitUntil { store.state == .unauthenticated }
        #expect(store.state == .unauthenticated)
    }

    // MARK: - Errors

    @Test("unknown provider throws .unsupportedProvider")
    func unsupportedProvider() async {
        let store = AuthenticationStore(authenticator: MockAuthenticator())
        do {
            try await store.signIn(using: .google)
            Issue.record("expected throw")
        } catch let error as AuthError {
            #expect(error.code == .unsupportedProvider)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("user cancellation propagates as .cancelled without exchanging")
    func cancellationPropagates() async {
        let authenticator = MockAuthenticator()
        let provider = MockCredentialProvider(providerID: .apple, result: .failure(AuthError.cancelled))
        let store = AuthenticationStore(authenticator: authenticator, credentialProviders: [provider])

        do {
            try await store.signIn(using: .apple)
            Issue.record("expected throw")
        } catch let error as AuthError {
            #expect(error.code == .cancelled)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
        #expect(authenticator.signInCallCount == 0)
    }

    @Test("non-AuthError from the provider is wrapped as .credentialAcquisitionFailed")
    func acquisitionFailureWrapped() async {
        let provider = MockCredentialProvider(providerID: .apple, result: .failure(TestError("boom")))
        let store = AuthenticationStore(authenticator: MockAuthenticator(), credentialProviders: [provider])

        do {
            try await store.signIn(using: .apple)
            Issue.record("expected throw")
        } catch let error as AuthError {
            #expect(error.code == .credentialAcquisitionFailed)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("exchange failure throws .sessionExchangeFailed and sets .error state")
    func exchangeFailure() async {
        let authenticator = MockAuthenticator()
        authenticator.signInError = TestError("exchange")
        let provider = MockCredentialProvider(providerID: .apple)
        let store = AuthenticationStore(authenticator: authenticator, credentialProviders: [provider])

        do {
            try await store.signIn(using: .apple)
            Issue.record("expected throw")
        } catch let error as AuthError {
            #expect(error.code == .sessionExchangeFailed)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
        #expect({ if case .error = store.state { return true } else { return false } }())
    }

    @Test("post-auth failure surfaces as .error state via the observer")
    func postAuthFailure() async throws {
        let user = AuthUser(id: "p")
        let authenticator = MockAuthenticator(stubbedUser: user)
        let postAuth = MockPostAuthenticationAction(error: TestError("provision"))
        let store = AuthenticationStore(authenticator: authenticator, postAuthentication: postAuth)

        authenticator.emit(user)
        await waitUntil { if case .error = store.state { return true } else { return false } }

        #expect({ if case .error = store.state { return true } else { return false } }())
    }

    @Test("signOut failure throws .signOutFailed")
    func signOutFailure() async {
        let authenticator = MockAuthenticator()
        authenticator.signOutError = TestError("signout")
        let store = AuthenticationStore(authenticator: authenticator)

        do {
            try await store.signOut()
            Issue.record("expected throw")
        } catch let error as AuthError {
            #expect(error.code == .signOutFailed)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}

@Suite("PostAuthenticationAction helpers")
struct PostAuthenticationActionTests {
    @Test("NoPostAuthentication does nothing")
    func noop() async throws {
        try await NoPostAuthentication().perform(for: AuthUser(id: "x"))
    }

    @Test("Composite runs all actions in order")
    func composite() async throws {
        let a = MockPostAuthenticationAction()
        let b = MockPostAuthenticationAction()
        let composite = CompositePostAuthentication([a, b])
        try await composite.perform(for: AuthUser(id: "y"))
        #expect(a.performCallCount == 1)
        #expect(b.performCallCount == 1)
    }
}

@Suite("Value types")
struct ValueTypeTests {
    @Test("AuthenticationState.isAuthenticated and user accessor")
    func stateAccessors() {
        let user = AuthUser(id: "z")
        #expect(AuthenticationState.authenticated(user).isAuthenticated)
        #expect(AuthenticationState.authenticated(user).user == user)
        #expect(!AuthenticationState.checking.isAuthenticated)
        #expect(AuthenticationState.unauthenticated.user == nil)
    }

    @Test("AuthenticationState equality matches v1 semantics")
    func stateEquality() {
        #expect(AuthenticationState.checking == .checking)
        #expect(AuthenticationState.unauthenticated == .unauthenticated)
        #expect(AuthenticationState.error(TestError()) == .error(TestError()))
        #expect(AuthenticationState.authenticated(AuthUser(id: "a"))
                != .authenticated(AuthUser(id: "b")))
        #expect(AuthenticationState.checking != .unauthenticated)
    }

    @Test("AuthProviderID is extensible via rawValue")
    func providerExtensible() {
        let custom = AuthProviderID(rawValue: "oidc.acme")
        #expect(custom.rawValue == "oidc.acme")
        #expect(AuthProviderID.apple == AuthProviderID(rawValue: "apple.com"))
    }

    @Test("AuthError.code maps representative cases")
    func errorCodes() {
        #expect(AuthError.cancelled.code == .cancelled)
        #expect(AuthError.unsupportedProvider(.google).code == .unsupportedProvider)
        #expect(AuthError.notAuthenticated.code == .notAuthenticated)
        #expect(AuthError.configuration("x").code == .configuration)
    }
}
