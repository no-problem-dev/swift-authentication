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

    @Test("signIn(using:) acquires a credential, exchanges it, and publishes the user")
    func signInUsingProviderFullFlow() async throws {
        let user = AuthUser(id: "abc", providerIDs: [.apple])
        let authenticator = MockAuthenticator(stubbedUser: user)
        let provider = MockCredentialProvider(providerID: .apple)
        let store = AuthenticationStore(authenticator: authenticator, credentialProviders: [provider])

        try await store.signIn(using: .apple)
        await waitUntil { store.state.isAuthenticated }

        #expect(provider.acquireCallCount == 1)
        #expect(authenticator.signInCallCount == 1)
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

    @Test("each emission replaces the state: signed in, signed out, signed in as someone else")
    func emissionsFollowTheAuthenticator() async throws {
        let authenticator = MockAuthenticator()
        let store = AuthenticationStore(authenticator: authenticator)
        let first = AuthUser(id: "first", isAnonymous: true)
        let second = AuthUser(id: "second", providerIDs: [.google])

        authenticator.emit(first)
        await waitUntil { store.state == .authenticated(first) }
        authenticator.emit(nil)
        await waitUntil { store.state == .unauthenticated }
        authenticator.emit(second)
        await waitUntil { store.state == .authenticated(second) }

        #expect(store.state == .authenticated(second))
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

    @Test("an email owned by another provider's account is thrown by name, not wrapped")
    func exchangeOtherProvidersEmail() async {
        let authenticator = MockAuthenticator()
        authenticator.signInError = AuthError.accountExistsWithDifferentProvider(provider: .apple, email: "owner@example.com")
        let provider = MockCredentialProvider(providerID: .apple)
        let store = AuthenticationStore(authenticator: authenticator, credentialProviders: [provider])

        await #expect {
            try await store.signIn(using: .apple)
        } throws: { ($0 as? AuthError)?.code == .accountExistsWithDifferentProvider }
        #expect({ if case .error(let error) = store.state { return (error as? AuthError)?.code == .accountExistsWithDifferentProvider } else { return false } }())
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

    // MARK: - Delete account

    @Test("deleteAccount delegates to the authenticator and unauthenticates via the observer")
    func deleteAccountSuccess() async throws {
        let user = AuthUser(id: "del")
        let authenticator = MockAuthenticator(stubbedUser: user)
        let store = AuthenticationStore(authenticator: authenticator)

        authenticator.emit(user)
        await waitUntil { store.state.isAuthenticated }

        try await store.deleteAccount()
        await waitUntil { store.state == .unauthenticated }

        #expect(authenticator.deleteCallCount == 1)
        #expect(authenticator.deletedWithAppleCodes == [nil], "no Apple link, no Apple sheet")
        #expect(store.state == .unauthenticated)
    }

    @Test("deleting an Apple-linked account asks Apple for a fresh code and passes it on")
    func deleteAccountPassesAppleCode() async throws {
        let user = AuthUser(id: "apple-user", providerIDs: [.apple])
        let authenticator = MockAuthenticator(stubbedUser: user)
        authenticator.storedUser = user
        let apple = MockCredentialProvider(
            providerID: .apple,
            result: .success(AuthCredential(provider: .apple, idToken: "id", rawNonce: "n", authorizationCode: "fresh-code"))
        )
        let store = AuthenticationStore(authenticator: authenticator, credentialProviders: [apple])

        try await store.deleteAccount()

        #expect(apple.acquireCallCount == 1)
        #expect(authenticator.deletedWithAppleCodes == ["fresh-code"])
    }

    @Test("backing out of Apple's sheet deletes nothing and throws .cancelled")
    func deleteAccountAppleCancelled() async {
        let user = AuthUser(id: "apple-user", providerIDs: [.apple])
        let authenticator = MockAuthenticator(stubbedUser: user)
        authenticator.storedUser = user
        let apple = MockCredentialProvider(providerID: .apple, result: .failure(AuthError.cancelled))
        let store = AuthenticationStore(authenticator: authenticator, credentialProviders: [apple])

        await #expect {
            try await store.deleteAccount()
        } throws: { ($0 as? AuthError)?.code == .cancelled }
        #expect(authenticator.deleteCallCount == 0)
    }

    @Test("an Apple-linked account with no Apple provider registered is deleted without a code")
    func deleteAccountWithoutAppleProvider() async throws {
        let user = AuthUser(id: "apple-user", providerIDs: [.apple])
        let authenticator = MockAuthenticator(stubbedUser: user)
        authenticator.storedUser = user
        let store = AuthenticationStore(authenticator: authenticator)

        try await store.deleteAccount()

        #expect(authenticator.deletedWithAppleCodes == [nil])
    }

    @Test("repeated deleteAccount calls are safe and keep the state unauthenticated")
    func deleteAccountIsIdempotent() async throws {
        let user = AuthUser(id: "del-twice")
        let authenticator = MockAuthenticator(stubbedUser: user)
        let store = AuthenticationStore(authenticator: authenticator)

        authenticator.emit(user)
        await waitUntil { store.state.isAuthenticated }

        try await store.deleteAccount()
        try await store.deleteAccount()
        await waitUntil { store.state == .unauthenticated }

        #expect(authenticator.deleteCallCount == 2)
        #expect(store.state == .unauthenticated)
    }

    @Test("deleteAccount failure throws .deleteAccountFailed and keeps the session")
    func deleteAccountFailure() async throws {
        let user = AuthUser(id: "del-fail")
        let authenticator = MockAuthenticator(stubbedUser: user)
        authenticator.deleteError = TestError("delete")
        let store = AuthenticationStore(authenticator: authenticator)

        authenticator.emit(user)
        await waitUntil { store.state.isAuthenticated }

        do {
            try await store.deleteAccount()
            Issue.record("expected throw")
        } catch let error as AuthError {
            #expect(error.code == .deleteAccountFailed)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
        #expect(authenticator.deleteCallCount == 1)
        #expect(store.state == .authenticated(user))   // A failure leaves the session signed in.
    }

    @Test("deleteAccount wraps .notAuthenticated from the authenticator as .deleteAccountFailed")
    func deleteAccountWhenNotAuthenticated() async {
        let authenticator = MockAuthenticator()
        authenticator.deleteError = AuthError.notAuthenticated
        let store = AuthenticationStore(authenticator: authenticator)

        do {
            try await store.deleteAccount()
            Issue.record("expected throw")
        } catch let error as AuthError {
            #expect(error.code == .deleteAccountFailed)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
        #expect(authenticator.deleteCallCount == 1)
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

    @Test("AuthenticationState equality compares users and ignores error payloads")
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
        #expect(AuthProviderID.apple == AuthProviderID(rawValue: "apple"))
        #expect(AuthProviderID.google == AuthProviderID(rawValue: "google"))
        #expect(AuthProviderID.anonymous == AuthProviderID(rawValue: "anonymous"))
    }

    @Test("AuthError.code maps representative cases")
    func errorCodes() {
        #expect(AuthError.cancelled.code == .cancelled)
        #expect(AuthError.unsupportedProvider(.google).code == .unsupportedProvider)
        #expect(AuthError.notAuthenticated.code == .notAuthenticated)
        #expect(AuthError.configuration("x").code == .configuration)
    }
}
