import Foundation
import APIClient
import Authentication

/// コアの ``AuthTokenProviding`` を swift-api-client の `AuthTokenProvider` に橋渡しする。
///
/// これにより、`AuthenticationFirebase` の `FirebaseTokenProvider`（vendor 非依存な
/// ``AuthTokenProviding``）を APIClient に注入できる。Firebase ターゲットは
/// swift-api-client に依存せず、API ターゲットは Firebase に依存しない。
public struct APITokenProviderAdapter: AuthTokenProvider {
    private let provider: any AuthTokenProviding

    /// `AuthTokenProviding` 実装を APIClient の `AuthTokenProvider` に変換する。
    ///
    /// - Parameter provider: コアの token プロバイダ（例: `FirebaseTokenProvider`）。
    public init(_ provider: any AuthTokenProviding) {
        self.provider = provider
    }

    /// トークンを取得して返す。
    ///
    /// - Returns: 有効なトークン文字列。取得できない場合は `nil`。
    public func getToken() async throws -> String? {
        await provider.token()
    }
}
