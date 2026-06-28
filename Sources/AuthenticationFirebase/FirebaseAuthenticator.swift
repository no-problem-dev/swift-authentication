import Foundation
@preconcurrency import FirebaseAuth
import Authentication

/// Firebase Authentication によるセッション交換（交換層の具象）。
///
/// 中立な ``AuthCredential`` を Firebase の資格情報に変換し、認証サーバと交換する。
public final class FirebaseAuthenticator: Authenticator, @unchecked Sendable {
    private let auth: Auth

    /// `FirebaseAuthenticator` を組み立てる。
    ///
    /// - Parameter auth: 使用する `Auth` インスタンス。テストでモック注入する場合に指定する。
    ///   省略時はシングルトン `Auth.auth()` を使用する。
    public init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    /// 現在のユーザー（未認証なら `nil`）。
    public func currentUser() async -> AuthUser? {
        auth.currentUser.map(FirebaseUserMapper.map)
    }

    /// `credential` を Firebase Authentication と交換し、認証済みユーザーを返す。
    ///
    /// `credential` が匿名認証に対応する場合（プロバイダ未設定）は `signInAnonymously()` を実行する。
    ///
    /// - Parameter credential: 取得層から渡された資格情報。
    /// - Returns: 認証済みユーザー。
    /// - Throws: Firebase の認証エラー。
    public func signIn(with credential: Authentication.AuthCredential) async throws -> AuthUser {
        let result: AuthDataResult
        if let firebaseCredential = try FirebaseCredentialMapper.makeCredential(from: credential) {
            result = try await auth.signIn(with: firebaseCredential)
        } else {
            result = try await auth.signInAnonymously()
        }
        return FirebaseUserMapper.map(result.user)
    }

    /// サインアウトする。
    ///
    /// - Throws: Firebase からのサインアウトエラー。
    public func signOut() async throws {
        try auth.signOut()
    }

    /// 現在のアカウントを削除する。
    ///
    /// - Throws: 未認証の場合は ``AuthError/notAuthenticated``。それ以外は Firebase のエラー。
    public func deleteAccount() async throws {
        guard let user = auth.currentUser else {
            throw AuthError.notAuthenticated
        }
        try await user.delete()
    }

    /// 認証状態の変化を流すストリーム。
    ///
    /// 購読開始時に現在の状態を即座に流す（Firebase の `addStateDidChangeListener` の挙動）。
    /// サインアウトまたは未認証の場合は `nil` を流す。
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
