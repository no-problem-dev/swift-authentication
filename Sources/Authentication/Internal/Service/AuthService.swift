import Foundation

/// 認証サービスプロトコル（内部使用）
protocol AuthService: Sendable {
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

/// 認証サービスの実装（内部使用）
final class AuthServiceImpl: AuthService {
    private let authRepository: AuthRepository

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    func isAuthenticated() async -> Bool {
        return await authRepository.isAuthenticated()
    }

    func signInWithGoogle() async -> SignInResult {
        return await authRepository.signInWithGoogle()
    }

    func signInWithApple(idToken: String, nonce: String) async -> SignInResult {
        return await authRepository.signInWithApple(idToken: idToken, nonce: nonce)
    }

    func signOut() async -> SignOutResult {
        return await authRepository.signOut()
    }

    func deleteAccount() async -> DeleteAccountResult {
        return await authRepository.deleteAccount()
    }

    func observeAuthState() -> AsyncStream<Bool> {
        return authRepository.observeAuthState()
    }
}
