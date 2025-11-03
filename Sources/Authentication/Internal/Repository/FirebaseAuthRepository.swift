import Foundation
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseCore
import GoogleSignIn
#if canImport(UIKit)
import UIKit
#endif

/// FirebaseAuthの実装（内部使用）
final class FirebaseAuthRepositoryImpl: AuthRepository {
    private let auth: Auth

    init() {
        self.auth = Auth.auth()
    }

    func isAuthenticated() async -> Bool {
        return auth.currentUser != nil
    }

    func signInWithGoogle() async -> SignInResult {
        #if os(iOS)
        do {
            // UIWindowSceneからrootViewControllerを取得
            guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let presentingViewController = await windowScene.windows.first?.rootViewController else {
                return .failure(.googleSignInFailed(
                    NSError(domain: "AuthError", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "画面の取得に失敗しました"
                    ])
                ))
            }

            // Firebase ClientIDを取得
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                return .failure(.googleSignInFailed(
                    NSError(domain: "AuthError", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Google Sign-In設定が見つかりません"
                    ])
                ))
            }

            // Google Sign-In設定
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

            // Google Sign-In実行
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                return .failure(.googleSignInFailed(
                    NSError(domain: "AuthError", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "IDトークンの取得に失敗しました"
                    ])
                ))
            }

            let accessToken = result.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            // Firebaseでサインイン
            _ = try await auth.signIn(with: credential)

            return .success
        } catch {
            return .failure(.googleSignInFailed(error))
        }
        #else
        return .failure(.googleSignInFailed(
            NSError(domain: "AuthError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Google Sign-In is only supported on iOS"
            ])
        ))
        #endif
    }

    func signInWithApple(idToken: String, nonce: String) async -> SignInResult {
        do {
            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: nil
            )

            _ = try await auth.signIn(with: credential)

            return .success
        } catch {
            return .failure(.appleSignInFailed(error))
        }
    }

    func signOut() async -> SignOutResult {
        do {
            try auth.signOut()
            return .success
        } catch {
            return .failure(.signOutFailed(error))
        }
    }

    func deleteAccount() async -> DeleteAccountResult {
        guard let user = auth.currentUser else {
            return .failure(.notAuthenticated)
        }

        do {
            try await user.delete()
            return .success
        } catch {
            return .failure(.deleteAccountFailed(error))
        }
    }

    func observeAuthState() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            nonisolated(unsafe) let handle = auth.addStateDidChangeListener { _, firebaseUser in
                continuation.yield(firebaseUser != nil)
            }

            continuation.onTermination = { _ in
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }
}
