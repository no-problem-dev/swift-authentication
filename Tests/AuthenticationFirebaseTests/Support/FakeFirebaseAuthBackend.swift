import Foundation
@preconcurrency import FirebaseAuth
import FirebaseCore
import Authentication
@testable import AuthenticationFirebase

/// A `FirebaseAuthBackend` that records every call, in order, and answers from what the test
/// set up. It stands in for Firebase only; the decisions under test stay in
/// `FirebaseAuthenticator`.
final class FakeFirebaseAuthBackend: FirebaseAuthBackend, @unchecked Sendable {
    enum Call: Equatable {
        case signIn, signInAnonymously, link, deleteCurrentUser, signOut, revokeToken
    }

    private let lock = NSLock()
    private var _calls: [Call] = []
    private var _exchangedCredentials: [FirebaseAuth.AuthCredential] = []

    var user: AuthUser?
    var signInResult: Result<AuthUser, any Error> = .success(AuthUser(id: "signed-in"))
    var linkError: (any Error)?
    var deleteError: (any Error)?
    var signOutError: (any Error)?

    var calls: [Call] { lock.withLock { _calls } }
    /// Every Firebase credential passed to `signIn(with:)`, in order.
    var exchangedCredentials: [FirebaseAuth.AuthCredential] { lock.withLock { _exchangedCredentials } }

    init(user: AuthUser? = nil) {
        self.user = user
    }

    private func record(_ call: Call) {
        lock.withLock { _calls.append(call) }
    }

    func currentUser() -> AuthUser? { user }

    func signIn(with credential: FirebaseAuth.AuthCredential) async throws -> AuthUser {
        record(.signIn)
        lock.withLock { _exchangedCredentials.append(credential) }
        return try signInResult.get()
    }

    func signInAnonymously() async throws -> AuthUser {
        record(.signInAnonymously)
        return AuthUser(id: "anonymous", isAnonymous: true)
    }

    func linkCurrentUser(with credential: FirebaseAuth.AuthCredential) async throws -> AuthUser? {
        record(.link)
        if let linkError { throw linkError }
        guard let user else { return nil }
        return AuthUser(id: user.id, isAnonymous: false, providerIDs: [Authentication.AuthProviderID(rawValue: credential.provider)])
    }

    func deleteCurrentUser() async throws {
        record(.deleteCurrentUser)
        if let deleteError { throw deleteError }
    }

    func signOut() throws {
        record(.signOut)
        if let signOutError { throw signOutError }
    }

    func revokeToken(authorizationCode: String) async throws {
        record(.revokeToken)
    }

    func stateChanges() -> AsyncStream<AuthUser?> {
        AsyncStream { $0.finish() }
    }
}

/// An `AccountDeletion` standing in for the server. It notes what the backend had already been
/// asked to do when the deletion ran, so a test can assert that signing out came after it.
final class RecordingAccountDeletion: AccountDeletion, @unchecked Sendable {
    private let lock = NSLock()
    private let backend: FakeFirebaseAuthBackend
    private var _deletedUserIDs: [String] = []
    private var _backendCallsAtDeletion: [FakeFirebaseAuthBackend.Call]?
    var error: (any Error)?

    var deletedUserIDs: [String] { lock.withLock { _deletedUserIDs } }
    var backendCallsAtDeletion: [FakeFirebaseAuthBackend.Call]? { lock.withLock { _backendCallsAtDeletion } }

    init(observing backend: FakeFirebaseAuthBackend) {
        self.backend = backend
    }

    func deleteAccount(of user: AuthUser) async throws {
        let calls = backend.calls
        lock.withLock {
            _deletedUserIDs.append(user.id)
            _backendCallsAtDeletion = calls
        }
        if let error { throw error }
    }
}

/// A Firebase app that is deliberately not the default one, configured once per test process.
///
/// Configuring the same name twice raises, and suites run in parallel, so every test that
/// needs one goes through this single lazily initialised value.
enum TestFirebaseApp {
    nonisolated(unsafe) static let secondary: FirebaseApp = {
        let name = "AuthenticationFirebaseTests"
        if let existing = FirebaseApp.app(name: name) { return existing }

        let options = FirebaseOptions(
            googleAppID: "1:123456789:ios:0123456789abcdef",
            gcmSenderID: "123456789"
        )
        options.projectID = "authentication-firebase-tests"
        options.apiKey = "AIzaSyNotARealKeyUsedOnlyByTests"
        FirebaseApp.configure(name: name, options: options)
        return FirebaseApp.app(name: name)!
    }()
}

enum FakeError: Error { case boom }
