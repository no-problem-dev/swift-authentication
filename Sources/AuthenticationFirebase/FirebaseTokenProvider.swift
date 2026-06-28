import Foundation
@preconcurrency import FirebaseAuth
import Authentication

/// Firebase ID トークンを供給する ``AuthTokenProviding`` 実装。
///
/// REST クライアントへ注入するには、`AuthenticationAPI` の `APITokenProviderAdapter`
/// で包む。
public final class FirebaseTokenProvider: AuthTokenProviding, @unchecked Sendable {
    private let auth: Auth

    public init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    public func token() async -> String? {
        guard let user = auth.currentUser else { return nil }
        do {
            return try await user.getIDToken()
        } catch {
            return nil
        }
    }
}
