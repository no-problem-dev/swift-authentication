import Foundation

/// 認証サーバとのセッション交換（交換層）。
///
/// プロバイダ別メソッドを持たず、``AuthCredential`` を受け取る単一の
/// ``signIn(with:)`` で交換する。具象は `AuthenticationFirebase` 等で実装。
public protocol Authenticator: Sendable {
    /// 現在のユーザー（未認証なら `nil`）。
    func currentUser() async -> AuthUser?

    /// 資格情報を認証サーバと交換し、認証済みユーザーを得る。
    func signIn(with credential: AuthCredential) async throws -> AuthUser

    /// サインアウトする。
    func signOut() async throws

    /// 現在のアカウントを削除する。
    func deleteAccount() async throws

    /// 認証状態の変化を流すストリーム。サインアウト時は `nil` を流す。
    ///
    /// 購読開始時に現在の状態を即座に流すことを想定
    /// （Firebase の `addStateDidChangeListener` と同じ挙動）。
    func authStateChanges() -> AsyncStream<AuthUser?>
}
