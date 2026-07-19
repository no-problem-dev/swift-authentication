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

    /// 現在の Firebase ID トークンを返す。
    ///
    /// - Returns: 未認証なら `nil`。
    /// - Throws: トークンの取得・リフレッシュに失敗した場合は Firebase のエラーを
    ///   そのまま伝播する（握りつぶして `nil` にはしない）。
    public func token() async throws -> String? {
        guard let user = auth.currentUser else { return nil }
        return try await user.getIDToken()
    }
}
