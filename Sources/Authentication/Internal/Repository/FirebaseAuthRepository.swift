import Foundation
import GeneralDomain
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseCore
import GoogleSignIn
#if canImport(UIKit)
import UIKit
#endif

typealias FirebaseUser = FirebaseAuth.User

/// FirebaseAuthの実装（内部使用）
final class FirebaseAuthRepositoryImpl: AuthRepository {
    private let auth: Auth

    init() {
        self.auth = Auth.auth()
    }

    func getCurrentUser() async -> GeneralDomain.User? {
        guard let firebaseUser = auth.currentUser else {
            return nil
        }
        return convertToUser(firebaseUser)
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
            let authResult = try await auth.signIn(with: credential)
            let user = convertToUser(authResult.user)

            return .success(user)
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

            let authResult = try await auth.signIn(with: credential)
            let user = convertToUser(authResult.user)

            return .success(user)
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

    func observeAuthState() -> AsyncStream<GeneralDomain.User?> {
        AsyncStream { continuation in
            nonisolated(unsafe) let handle = auth.addStateDidChangeListener { _, firebaseUser in
                if let firebaseUser = firebaseUser {
                    let user = self.convertToUser(firebaseUser)
                    continuation.yield(user)
                } else {
                    continuation.yield(nil)
                }
            }

            continuation.onTermination = { _ in
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }

    // MARK: - Private Helpers

    private func convertToUser(_ firebaseUser: FirebaseUser) -> GeneralDomain.User {
        return GeneralDomain.User(
            id: firebaseUser.uid,
            email: firebaseUser.email,
            displayName: firebaseUser.displayName,
            photoURL: firebaseUser.photoURL?.absoluteString,
            createdAt: firebaseUser.metadata.creationDate ?? Date()
        )
    }
}
