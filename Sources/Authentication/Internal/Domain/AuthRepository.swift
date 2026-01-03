import Foundation

/// Firebase認証リポジトリプロトコル
protocol AuthRepository: Sendable {
    func isAuthenticated() async -> Bool
    func signInWithGoogle() async -> SignInResult
    func signInWithApple(idToken: String, nonce: String) async -> SignInResult
    func signOut() async -> SignOutResult
    func deleteAccount() async -> DeleteAccountResult
    func observeAuthState() -> AsyncStream<Bool>
}
