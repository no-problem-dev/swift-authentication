import Testing
import Foundation
@preconcurrency import FirebaseAuth
import Authentication
@testable import AuthenticationFirebase

/// Covers the decisions `FirebaseAuthenticator` makes on top of Firebase: which call a
/// credential goes to, how a collision is translated and resumed, and what deleting an account
/// does in which order. Firebase itself is replaced by `FakeFirebaseAuthBackend`.
@Suite("FirebaseAuthenticator")
struct FirebaseAuthenticatorTests {

    private let anonymous = AuthUser(id: "anon-1", isAnonymous: true)
    private let appleCredential = Authentication.AuthCredential(provider: .apple, idToken: "apple-id", rawNonce: "nonce")
    private let googleCredential = Authentication.AuthCredential(provider: .google, idToken: "g-id", accessToken: "g-access")

    // MARK: - signIn

    @Test("an anonymous credential opens an anonymous session instead of an exchange")
    func signInAnonymous() async throws {
        let backend = FakeFirebaseAuthBackend()
        let authenticator = FirebaseAuthenticator(backend: backend)

        let user = try await authenticator.signIn(with: .anonymous)

        #expect(user.isAnonymous)
        #expect(backend.calls == [.signInAnonymously])
    }

    @Test("a provider credential is converted and exchanged", arguments: [
        (Authentication.AuthProviderID.apple, "apple.com"),
        (Authentication.AuthProviderID.google, "google.com")
    ])
    func signInExchangesCredential(provider: Authentication.AuthProviderID, firebaseProvider: String) async throws {
        let backend = FakeFirebaseAuthBackend()
        backend.signInResult = .success(AuthUser(id: "u-1", providerIDs: [provider]))
        let authenticator = FirebaseAuthenticator(backend: backend)
        let credential = provider == .apple ? appleCredential : googleCredential

        let user = try await authenticator.signIn(with: credential)

        #expect(user.id == "u-1")
        #expect(backend.calls == [.signIn])
        #expect(backend.exchangedCredentials.map(\.provider) == [firebaseProvider])
    }

    @Test("a credential missing a required field is refused before anything reaches Firebase")
    func signInRejectsIncompleteCredential() async {
        let backend = FakeFirebaseAuthBackend()
        let authenticator = FirebaseAuthenticator(backend: backend)
        let noNonce = Authentication.AuthCredential(provider: .apple, idToken: "apple-id")

        await #expect(throws: FirebaseAuthenticatorError.invalidCredential(.apple)) {
            _ = try await authenticator.signIn(with: noNonce)
        }
        #expect(backend.calls.isEmpty)
    }

    @Test("a sign-in failure from Firebase propagates")
    func signInPropagatesFailure() async {
        let backend = FakeFirebaseAuthBackend()
        backend.signInResult = .failure(FakeError.boom)
        let authenticator = FirebaseAuthenticator(backend: backend)

        await #expect(throws: FakeError.self) {
            _ = try await authenticator.signIn(with: googleCredential)
        }
    }

    // MARK: - link

    @Test("link keeps the uid and reports the linked provider")
    func linkKeepsUID() async throws {
        let backend = FakeFirebaseAuthBackend(user: anonymous)
        let authenticator = FirebaseAuthenticator(backend: backend)

        let user = try await authenticator.link(with: appleCredential)

        #expect(user.id == anonymous.id)
        #expect(!user.isAnonymous)
        #expect(user.providerIDs == [.apple])
        #expect(backend.calls == [.link], "linking must not sign in, which would replace the uid")
    }

    @Test("link with nobody signed in throws .notAuthenticated")
    func linkWithoutUser() async {
        let authenticator = FirebaseAuthenticator(backend: FakeFirebaseAuthBackend(user: nil))

        await #expect {
            _ = try await authenticator.link(with: appleCredential)
        } throws: { ($0 as? AuthError)?.code == .notAuthenticated }
    }

    @Test("an anonymous or incomplete credential cannot be linked", arguments: [
        Authentication.AuthCredential.anonymous,
        Authentication.AuthCredential(provider: .google, idToken: "only-id")
    ])
    func linkRejectsUnconvertible(credential: Authentication.AuthCredential) async {
        let backend = FakeFirebaseAuthBackend(user: anonymous)
        let authenticator = FirebaseAuthenticator(backend: backend)

        await #expect {
            _ = try await authenticator.link(with: credential)
        } throws: { ($0 as? AuthError)?.code == .linkFailed }
        #expect(backend.calls.isEmpty)
    }

    @Test("Firebase's credentialAlreadyInUse becomes a typed collision carrying the replacement")
    func linkCollisionIsTyped() async throws {
        let renewed = GoogleAuthProvider.credential(withIDToken: "renewed-id", accessToken: "renewed-access")
        let backend = FakeFirebaseAuthBackend(user: anonymous)
        backend.linkError = Self.credentialAlreadyInUse(email: "owner@example.com", renewed: renewed)
        let authenticator = FirebaseAuthenticator(backend: backend)

        let collision = try await Self.collision(from: authenticator, linking: googleCredential)

        #expect(collision.provider == .google)
        #expect(collision.email == "owner@example.com")
        #expect((collision.renewedCredential as? FirebaseRenewedCredential)?.credential === renewed)
    }

    @Test("any other link failure is wrapped as .linkFailed")
    func linkOtherFailure() async {
        let backend = FakeFirebaseAuthBackend(user: anonymous)
        backend.linkError = NSError(domain: AuthErrors.domain, code: AuthErrorCode.providerAlreadyLinked.rawValue)
        let authenticator = FirebaseAuthenticator(backend: backend)

        await #expect {
            _ = try await authenticator.link(with: appleCredential)
        } throws: { ($0 as? AuthError)?.code == .linkFailed }
    }

    // MARK: - Resolving a collision

    /// The defect this exists to prevent: exchanging the credential that collided again. For
    /// Apple its nonce is already spent, and Firebase answers "Duplicate credential received".
    @Test("resolving signs in with Firebase's replacement, never with the credential that collided")
    func resolveUsesReplacement() async throws {
        let renewed = OAuthProvider.appleCredential(withIDToken: "renewed-id", rawNonce: "renewed-nonce", fullName: nil)
        let backend = FakeFirebaseAuthBackend(user: anonymous)
        backend.linkError = Self.credentialAlreadyInUse(email: nil, renewed: renewed)
        backend.signInResult = .success(AuthUser(id: "owner-7", providerIDs: [.apple]))
        let authenticator = FirebaseAuthenticator(backend: backend)

        let collision = try await Self.collision(from: authenticator, linking: appleCredential)
        let user = try await authenticator.signIn(resolving: collision)

        #expect(user.id == "owner-7")
        #expect(backend.calls == [.link, .signIn])
        #expect(backend.exchangedCredentials.count == 1)
        #expect(backend.exchangedCredentials.first === renewed)
    }

    @Test("without a replacement, resolving rethrows the collision and exchanges nothing")
    func resolveWithoutReplacement() async throws {
        let backend = FakeFirebaseAuthBackend(user: anonymous)
        backend.linkError = Self.credentialAlreadyInUse(email: "owner@example.com", renewed: nil)
        let authenticator = FirebaseAuthenticator(backend: backend)

        let collision = try await Self.collision(from: authenticator, linking: appleCredential)
        #expect(collision.renewedCredential == nil)

        await #expect {
            _ = try await authenticator.signIn(resolving: collision)
        } throws: { ($0 as? AuthError)?.code == .credentialAlreadyInUse }
        #expect(backend.calls == [.link])
    }

    @Test("a replacement from some other authenticator is not used")
    func resolveIgnoresForeignReplacement() async {
        let backend = FakeFirebaseAuthBackend(user: anonymous)
        let authenticator = FirebaseAuthenticator(backend: backend)

        await #expect {
            _ = try await authenticator.signIn(
                resolving: CredentialCollision(provider: .apple, renewedCredential: "not-a-firebase-credential")
            )
        } throws: { ($0 as? AuthError)?.code == .credentialAlreadyInUse }
        #expect(backend.calls.isEmpty)
    }

    // MARK: - deleteAccount

    @Test("with nobody signed in, deleteAccount throws .notAuthenticated and deletes nothing")
    func deleteWithoutUser() async {
        let backend = FakeFirebaseAuthBackend(user: nil)
        let deletion = RecordingAccountDeletion(observing: backend)
        let authenticator = FirebaseAuthenticator(backend: backend, accountDeletion: deletion)

        await #expect {
            try await authenticator.deleteAccount()
        } throws: { ($0 as? AuthError)?.code == .notAuthenticated }
        #expect(deletion.deletedUserIDs.isEmpty)
        #expect(backend.calls.isEmpty)
    }

    @Test("with an account deletion, the server deletes and only then is the session cleared")
    func deleteThroughServer() async throws {
        let backend = FakeFirebaseAuthBackend(user: anonymous)
        let deletion = RecordingAccountDeletion(observing: backend)
        let authenticator = FirebaseAuthenticator(backend: backend, accountDeletion: deletion)

        try await authenticator.deleteAccount()

        #expect(deletion.deletedUserIDs == [anonymous.id])
        #expect(deletion.backendCallsAtDeletion == [], "signing out first would discard the bearer a retry needs")
        #expect(backend.calls == [.signOut], "the device must not delete the account itself")
    }

    @Test("when the server deletion fails, the session stays so the request can be retried")
    func deleteThroughServerFails() async {
        let backend = FakeFirebaseAuthBackend(user: anonymous)
        let deletion = RecordingAccountDeletion(observing: backend)
        deletion.error = FakeError.boom
        let authenticator = FirebaseAuthenticator(backend: backend, accountDeletion: deletion)

        await #expect(throws: FakeError.self) {
            try await authenticator.deleteAccount()
        }
        #expect(backend.calls.isEmpty)
    }

    @Test("without an account deletion, the account is deleted on the device and the session cleared")
    func deleteOnDevice() async throws {
        let backend = FakeFirebaseAuthBackend(user: anonymous)
        let authenticator = FirebaseAuthenticator(backend: backend)

        try await authenticator.deleteAccount()

        #expect(backend.calls == [.deleteCurrentUser, .signOut])
    }

    @Test("a device deletion Firebase refuses (requiresRecentLogin) propagates and keeps the session")
    func deleteOnDeviceRefused() async {
        let backend = FakeFirebaseAuthBackend(user: anonymous)
        backend.deleteError = NSError(domain: AuthErrors.domain, code: AuthErrorCode.requiresRecentLogin.rawValue)
        let authenticator = FirebaseAuthenticator(backend: backend)

        await #expect {
            try await authenticator.deleteAccount()
        } throws: { ($0 as NSError).code == AuthErrorCode.requiresRecentLogin.rawValue }
        #expect(backend.calls == [.deleteCurrentUser])
    }

    @Test("an account that is gone but whose session would not clear reports .signOutFailed")
    func deleteThenSignOutFails() async {
        let backend = FakeFirebaseAuthBackend(user: anonymous)
        backend.signOutError = FakeError.boom
        let deletion = RecordingAccountDeletion(observing: backend)
        let authenticator = FirebaseAuthenticator(backend: backend, accountDeletion: deletion)

        await #expect {
            try await authenticator.deleteAccount()
        } throws: { ($0 as? AuthError)?.code == .signOutFailed }
        #expect(deletion.deletedUserIDs == [anonymous.id])
    }

    // MARK: - Helpers

    /// The error Firebase raises when another account owns the credential being linked.
    private static func credentialAlreadyInUse(email: String?, renewed: FirebaseAuth.AuthCredential?) -> NSError {
        var userInfo: [String: Any] = [:]
        if let email { userInfo[AuthErrors.userInfoEmailKey] = email }
        if let renewed { userInfo[AuthErrors.userInfoUpdatedCredentialKey] = renewed }
        return NSError(domain: AuthErrors.domain, code: AuthErrorCode.credentialAlreadyInUse.rawValue, userInfo: userInfo)
    }

    /// Links and returns the collision the authenticator threw, failing the test otherwise.
    private static func collision(
        from authenticator: FirebaseAuthenticator,
        linking credential: Authentication.AuthCredential
    ) async throws -> CredentialCollision {
        do {
            _ = try await authenticator.link(with: credential)
        } catch let AuthError.credentialAlreadyInUse(collision) {
            return collision
        }
        Issue.record("expected a collision")
        throw FakeError.boom
    }
}

@Suite("FirebaseCredentialMapper")
struct FirebaseCredentialMapperTests {
    @Test("Apple and Google credentials convert to their Firebase providers; anonymous to nil")
    func converts() throws {
        let apple = try FirebaseCredentialMapper.makeCredential(from: Authentication.AuthCredential(provider: .apple, idToken: "i", rawNonce: "n"))
        let google = try FirebaseCredentialMapper.makeCredential(
            from: Authentication.AuthCredential(provider: .google, idToken: "i", accessToken: "a")
        )
        #expect(apple?.provider == "apple.com")
        #expect(google?.provider == "google.com")
        #expect(try FirebaseCredentialMapper.makeCredential(from: .anonymous) == nil)
    }

    @Test("a provider Firebase cannot exchange here is refused")
    func refusesUnknownProvider() {
        let custom = Authentication.AuthProviderID(rawValue: "oidc.acme")
        #expect(throws: FirebaseAuthenticatorError.invalidCredential(custom)) {
            _ = try FirebaseCredentialMapper.makeCredential(from: Authentication.AuthCredential(provider: custom, idToken: "i"))
        }
    }
}

@Suite("FirebaseTokenProvider")
struct FirebaseTokenProviderTests {
    @Test("nobody signed in yields nil whether or not a refresh is forced", arguments: [false, true])
    func signedOutYieldsNil(forceRefresh: Bool) async throws {
        let provider = FirebaseTokenProvider(auth: Auth.auth(app: TestFirebaseApp.secondary))
        #expect(try await provider.token(forceRefresh: forceRefresh) == nil)
    }
}
