import Foundation
import AuthenticationServices

/// 認証ユースケース
public protocol AuthenticationUseCase: Sendable {
    func isAuthenticated() async -> Bool
    func signInWithGoogle() async throws
    func signInWithApple(authorization: ASAuthorization) async throws
    func signOut() async throws
    func deleteAccount() async throws
    func observeAuthState() -> AsyncStream<AuthenticationState>
    func signOutOnFreshInstall() async
    static func handleGoogleSignInURL(_ url: URL) -> Bool
}
