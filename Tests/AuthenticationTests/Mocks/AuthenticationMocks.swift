import Foundation
@testable import Authentication

/// テスト用の `Authenticator` モック。
///
/// `signIn(with:)` 成功時に `authStateChanges()` ストリームへユーザーを流すことで、
/// Firebase の `addStateDidChangeListener` と同じ挙動を再現する。
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

    /// 外部要因（cold start / token refresh / 外部サインアウト）による状態変化を模擬する。
    func emit(_ user: AuthUser?) {
        continuation.yield(user)
    }
}

/// テスト用の `CredentialProvider` モック。
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

/// テスト用の `PostAuthenticationAction` モック。
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
