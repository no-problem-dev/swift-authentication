import Foundation
@testable import Authentication

/// An authenticator the test drives by hand.
///
/// A successful `signIn(with:)` pushes the user into the `authStateChanges()` stream, the way
/// an authenticator reports a new session.
@MainActor
final class MockAuthenticator: Authenticator {
    var stubbedUser: AuthUser
    var signInError: (any Error)?
    var signOutError: (any Error)?
    var deleteError: (any Error)?
    /// What `link(with:)` returns; `nil` makes it throw ``linkError`` or `notAuthenticated`.
    var linkedUser: AuthUser?
    var linkError: (any Error)?
    /// What `signIn(resolving:)` does. `nil` rethrows the collision, which is how an
    /// authenticator says it cannot use the collided credential again.
    var resolvedUser: AuthUser?
    var resolveError: (any Error)?
    /// What `unlink(_:)` returns; `nil` makes it throw `notAuthenticated`.
    var unlinkedUser: AuthUser?
    /// What `signInExisting(with:)` finds; `nil` means no account owns the credential.
    var existingUser: AuthUser?
    var existingError: (any Error)?
    /// What `currentUser()` reports.
    var storedUser: AuthUser?

    private(set) var signInCallCount = 0
    private(set) var signedInCredentials: [AuthCredential] = []
    private(set) var signOutCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var deletedWithAppleCodes: [String?] = []
    private(set) var linkedCredentials: [AuthCredential] = []
    private(set) var resolveCallCount = 0
    private(set) var unlinkedProviders: [AuthProviderID] = []
    private(set) var existingCredentials: [AuthCredential] = []

    private let continuation: AsyncStream<AuthUser?>.Continuation
    private let stream: AsyncStream<AuthUser?>

    init(stubbedUser: AuthUser = AuthUser(id: "user-1")) {
        self.stubbedUser = stubbedUser
        (stream, continuation) = AsyncStream<AuthUser?>.makeStream()
    }

    func currentUser() async -> AuthUser? { storedUser }

    func signIn(with credential: AuthCredential) async throws -> AuthUser {
        signInCallCount += 1
        signedInCredentials.append(credential)
        if let signInError { throw signInError }
        continuation.yield(stubbedUser)
        return stubbedUser
    }

    func link(with credential: AuthCredential) async throws -> AuthUser {
        linkedCredentials.append(credential)
        if let linkError { throw linkError }
        guard let linkedUser else { throw AuthError.notAuthenticated }
        return linkedUser
    }

    func unlink(_ provider: AuthProviderID) async throws -> AuthUser {
        unlinkedProviders.append(provider)
        guard let unlinkedUser else { throw AuthError.notAuthenticated }
        return unlinkedUser
    }

    func signInExisting(with credential: AuthCredential) async throws -> AuthUser? {
        existingCredentials.append(credential)
        if let existingError { throw existingError }
        if let existingUser { continuation.yield(existingUser) }
        return existingUser
    }

    func signIn(resolving collision: CredentialCollision) async throws -> AuthUser {
        resolveCallCount += 1
        if let resolveError { throw resolveError }
        guard let resolvedUser else { throw AuthError.credentialAlreadyInUse(collision) }
        continuation.yield(resolvedUser)
        return resolvedUser
    }

    func signOut() async throws {
        signOutCallCount += 1
        if let signOutError { throw signOutError }
        continuation.yield(nil)
    }

    func deleteAccount(appleAuthorizationCode: String?) async throws {
        deleteCallCount += 1
        deletedWithAppleCodes.append(appleAuthorizationCode)
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

/// A token provider that returns a fixed token per freshness and records what it was asked.
final class MockTokenProvider: AuthTokenProviding, @unchecked Sendable {
    private let lock = NSLock()
    private let cached: String?
    private let refreshed: String?
    private var _requests: [Bool] = []

    var requests: [Bool] { lock.withLock { _requests } }

    init(cached: String?, refreshed: String?) {
        self.cached = cached
        self.refreshed = refreshed
    }

    func token(forceRefresh: Bool) async throws -> String? {
        lock.withLock { _requests.append(forceRefresh) }
        return forceRefresh ? refreshed : cached
    }
}

struct TestError: Error, Equatable {
    let label: String
    init(_ label: String = "test") { self.label = label }
}
