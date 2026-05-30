import Foundation
@preconcurrency import FirebaseAuth
import Authentication

/// Firebase Authentication によるセッション交換（交換層の具象）。
///
/// 中立な ``AuthCredential`` を Firebase の資格情報に変換し、認証サーバと交換します。
public final class FirebaseAuthenticator: Authenticator, @unchecked Sendable {
    private let auth: Auth

    public init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    public func currentUser() async -> AuthUser? {
        auth.currentUser.map(FirebaseUserMapper.map)
    }

    public func signIn(with credential: Authentication.AuthCredential) async throws -> AuthUser {
        let result: AuthDataResult
        if let firebaseCredential = try FirebaseCredentialMapper.makeCredential(from: credential) {
            result = try await auth.signIn(with: firebaseCredential)
        } else {
            result = try await auth.signInAnonymously()
        }
        return FirebaseUserMapper.map(result.user)
    }

    public func signOut() async throws {
        try auth.signOut()
    }

    public func deleteAccount() async throws {
        guard let user = auth.currentUser else {
            throw AuthError.notAuthenticated
        }
        try await user.delete()
    }

    public func authStateChanges() -> AsyncStream<AuthUser?> {
        AsyncStream { continuation in
            nonisolated(unsafe) let handle = auth.addStateDidChangeListener { _, user in
                continuation.yield(user.map(FirebaseUserMapper.map))
            }
            continuation.onTermination = { _ in
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }
}
