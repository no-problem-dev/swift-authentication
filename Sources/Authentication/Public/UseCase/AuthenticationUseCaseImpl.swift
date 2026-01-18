import Foundation
import APIClient
import AuthenticationServices
import CryptoKit
import GoogleSignIn

/// 認証ユースケース実装
public struct AuthenticationUseCaseImpl: AuthenticationUseCase {
    private let authService: AuthService
    private let apiAuthRepository: APIAuthRepository

    public init(apiClient: some APIExecutable, authenticationPath: String) {
        let firebaseAuthRepository = FirebaseAuthRepositoryImpl()
        let apiAuthRepository = APIAuthRepositoryImpl(apiClient: apiClient, authenticationPath: authenticationPath)

        self.authService = AuthServiceImpl(authRepository: firebaseAuthRepository)
        self.apiAuthRepository = apiAuthRepository
    }

    public func isAuthenticated() async -> Bool {
        return await authService.isAuthenticated()
    }

    public func signInWithGoogle() async throws {
        let firebaseResult = await authService.signInWithGoogle()

        guard case .success = firebaseResult else {
            if case .failure(let error) = firebaseResult {
                throw error
            }
            throw AuthError.unknown(NSError(domain: "AuthError", code: -1))
        }

        do {
            _ = try await apiAuthRepository.initializeUser()
        } catch {
            throw AuthError.apiAuthFailed(error)
        }
    }

    public func signInWithApple(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.appleSignInFailed(
                NSError(domain: "AuthError", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Apple Sign-In credentials not found"
                ])
            )
        }

        let nonce = generateNonce()

        let firebaseResult = await authService.signInWithApple(
            idToken: idTokenString,
            nonce: nonce
        )

        guard case .success = firebaseResult else {
            if case .failure(let error) = firebaseResult {
                throw error
            }
            throw AuthError.unknown(NSError(domain: "AuthError", code: -1))
        }

        do {
            _ = try await apiAuthRepository.initializeUser()
        } catch {
            throw AuthError.apiAuthFailed(error)
        }
    }

    public func signOut() async throws {
        let result = await authService.signOut()

        if case .failure(let error) = result {
            throw error
        }
    }

    public func deleteAccount() async throws {
        let result = await authService.deleteAccount()

        if case .failure(let error) = result {
            throw error
        }
    }

    public func observeAuthState() -> AsyncStream<AuthenticationState> {
        let apiAuthRepository = self.apiAuthRepository

        return AsyncStream { continuation in
            let task = Task {
                var hasInitialized = false

                for await isAuthenticated in authService.observeAuthState() {
                    if isAuthenticated {
                        // 初回のみ initializeUser() を呼ぶ
                        // Firebase Auth は状態変更のたびに複数回イベントをemitするため
                        if !hasInitialized {
                            do {
                                _ = try await apiAuthRepository.initializeUser()
                                hasInitialized = true
                                continuation.yield(.authenticated)
                            } catch {
                                continuation.yield(.error(error))
                            }
                        } else {
                            // 2回目以降は initializeUser() をスキップ
                            continuation.yield(.authenticated)
                        }
                    } else {
                        // サインアウト時はフラグをリセット
                        hasInitialized = false
                        continuation.yield(.unauthenticated)
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func signOutOnFreshInstall() async {
        _ = await authService.signOut()
    }

    public static func handleGoogleSignInURL(_ url: URL) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    private func generateNonce() -> String {
        let nonce = randomNonceString()
        return sha256(nonce)
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError(
                "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
            )
        }

        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}
