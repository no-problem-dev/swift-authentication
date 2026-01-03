import Foundation

/// 認証サービスプロトコル
protocol AuthService: Sendable {
    func isAuthenticated() async -> Bool
    func signInWithGoogle() async -> SignInResult
    func signInWithApple(idToken: String, nonce: String) async -> SignInResult
    func signOut() async -> SignOutResult
    func deleteAccount() async -> DeleteAccountResult
    func observeAuthState() -> AsyncStream<Bool>
}

/// 認証サービス実装
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
