import Foundation
@testable import Authentication

/// An authenticator the test drives by hand.
///
/// A successful `signIn(with:)` pushes the user into the `authStateChanges()` stream, which
/// reproduces how Firebase's state-change listener behaves.
@MainActor
final class MockAuthenticator: Authenticator {
    var stubbedUser: AuthUser
    var signInError: (any Error)?
    var signOutError: (any Error)?
    var deleteError: (any Error)?

    private(set) var signInCallCount = 0
    private(set) var signedInCredentials: [AuthCredential] = []
    private(set) var signOutCallCount = 0
    private(set) var deleteCallCount = 0

    private let continuation: AsyncStream<AuthUser?>.Continuation
    private let stream: AsyncStream<AuthUser?>

    init(stubbedUser: AuthUser = AuthUser(id: "user-1")) {
        self.stubbedUser = stubbedUser
        (stream, continuation) = AsyncStream<AuthUser?>.makeStream()
    }

    nonisolated func currentUser() async -> AuthUser? { nil }

    func signIn(with credential: AuthCredential) async throws -> AuthUser {
        signInCallCount += 1
        signedInCredentials.append(credential)
        if let signInError { throw signInError }
        continuation.yield(stubbedUser)
        return stubbedUser
    }

    func signOut() async throws {
        signOutCallCount += 1
        if let signOutError { throw signOutError }
        continuation.yield(nil)
    }

    func deleteAccount() async throws {
        deleteCallCount += 1
        if let deleteError { throw deleteError }
        continuation.yield(nil)
    }

    nonisolated func authStateChanges() -> AsyncStream<AuthUser?> { stream }

    /// Emits a state change the app did not ask for: a cold start, a token refresh, or a
    /// sign-out that happened elsewhere.
    func emit(_ user: AuthUser?) {
        continuation.yield(user)
    }
}

/// A credential provider that returns a canned result instead of presenting UI.
final class MockCredentialProvider: CredentialProvider, @unchecked Sendable {
    let providerID: AuthProviderID
    var result: Result<AuthCredential, any Error>
    private(set) var acquireCallCount = 0

    init(providerID: AuthProviderID, result: Result<AuthCredential, any Error>? = nil) {
        self.providerID = providerID
        self.result = result ?? .success(AuthCredential(provider: providerID, idToken: "token"))
    }

    func acquireCredential() async throws -> AuthCredential {
        acquireCallCount += 1
        return try result.get()
    }
}

/// A post-authentication action that records who it ran for, and can be made to fail.
final class MockPostAuthenticationAction: PostAuthenticationAction, @unchecked Sendable {
    var error: (any Error)?
    private let lock = NSLock()
    private var _performCallCount = 0
    private var _performedUserIDs: [String] = []

    var performCallCount: Int { lock.withLock { _performCallCount } }
    var performedUserIDs: [String] { lock.withLock { _performedUserIDs } }

    init(error: (any Error)? = nil) {
        self.error = error
    }

    func perform(for user: AuthUser) async throws {
        lock.withLock {
            _performCallCount += 1
            _performedUserIDs.append(user.id)
        }
        if let error { throw error }
    }
}

struct TestError: Error, Equatable {
    let label: String
    init(_ label: String = "test") { self.label = label }
}
