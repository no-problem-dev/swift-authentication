import Foundation

/// Firebase認証リポジトリプロトコル（内部使用）
protocol AuthRepository: Sendable {
    /// 現在の認証状態を確認
    func isAuthenticated() async -> Bool

    /// Googleでサインイン
    func signInWithGoogle() async -> SignInResult

    /// Appleでサインイン
    func signInWithApple(idToken: String, nonce: String) async -> SignInResult

    /// サインアウト
    func signOut() async -> SignOutResult

    /// アカウント削除
    func deleteAccount() async -> DeleteAccountResult

    /// 認証状態の監視
    func observeAuthState() -> AsyncStream<Bool>
}
