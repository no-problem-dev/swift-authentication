import Foundation
import APIClient
@preconcurrency import FirebaseAuth

/// Firebase認証トークンプロバイダー
///
/// `APIClient`にFirebase IDトークンを提供します。
/// バックエンドAPI呼び出し時に自動的に認証ヘッダーを付与するために使用します。
///
/// 使用例:
/// ```swift
/// let authTokenProvider = FirebaseAuthTokenProvider()
/// let apiClient = APIClientImpl(
///     baseURL: baseURL,
///     authTokenProvider: authTokenProvider
/// )
/// ```
public final class FirebaseAuthTokenProvider: AuthTokenProvider {
    private let auth: Auth

    public init() {
        self.auth = Auth.auth()
    }

    public func getToken() async -> String? {
        guard let currentUser = auth.currentUser else {
            return nil
        }

        do {
            return try await currentUser.getIDToken()
        } catch {
            print("Failed to get Firebase ID token: \(error)")
            return nil
        }
    }
}
