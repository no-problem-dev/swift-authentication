import Foundation
import GeneralDomain
import AuthenticationServices

/// 認証機能の公開ユースケース
///
/// Firebase認証とバックエンドAPI認証を統合管理します。
/// 環境値経由で注入して使用してください。
public protocol AuthenticationUseCase: Sendable {
    /// 現在ログイン中のユーザーを取得
    ///
    /// Firebase認証状態を確認し、ログイン済みユーザーを返します。
    ///
    /// - Returns: ログイン中のユーザー。未ログインの場合はnil
    func getCurrentUser() async -> User?

    /// Googleアカウントでサインイン
    ///
    /// Firebase認証とバックエンドAPI認証の両方を実行します。
    /// 認証完了後、`observeAuthState()`で状態変更が通知されます。
    ///
    /// - Throws: 認証エラー（`AuthError`）
    func signInWithGoogle() async throws

    /// Apple IDでサインイン
    ///
    /// Firebase認証とバックエンドAPI認証の両方を実行します。
    /// 認証完了後、`observeAuthState()`で状態変更が通知されます。
    ///
    /// - Parameter authorization: Apple Sign-Inから取得した認証情報
    /// - Throws: 認証エラー（`AuthError`）
    func signInWithApple(authorization: ASAuthorization) async throws

    /// サインアウト
    ///
    /// Firebase認証からサインアウトします。
    ///
    /// - Throws: サインアウトエラー
    func signOut() async throws

    /// アカウント削除
    ///
    /// Firebase認証アカウントとバックエンドのユーザーデータを削除します。
    ///
    /// - Throws: 削除エラー
    func deleteAccount() async throws

    /// 認証状態の監視
    ///
    /// Firebase認証とバックエンドAPI認証の統合状態をリアルタイムで監視します。
    /// ログイン状態が変化すると新しい`AuthenticationState`が流れます。
    ///
    /// - Returns: 認証状態のストリーム
    func observeAuthState() -> AsyncStream<AuthenticationState>

    /// 初回インストール時のサインアウト処理
    ///
    /// アプリ初回起動時に古い認証情報をクリアするために使用します。
    func signOutOnFreshInstall() async

    /// Google Sign-In URLハンドリング
    ///
    /// AppDelegateのURL handling経由で呼び出してください。
    ///
    /// - Parameter url: 処理するURL
    /// - Returns: URLが処理された場合はtrue
    static func handleGoogleSignInURL(_ url: URL) -> Bool
}
