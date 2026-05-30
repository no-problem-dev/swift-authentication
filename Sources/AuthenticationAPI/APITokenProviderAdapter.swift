import Foundation
import APIClient
import Authentication

/// コアの ``AuthTokenProviding`` を swift-api-client の `AuthTokenProvider` に橋渡しする。
///
/// これにより、`AuthenticationFirebase` の `FirebaseTokenProvider`（vendor 非依存な
/// ``AuthTokenProviding``）を APIClient に注入できます。Firebase ターゲットは
/// swift-api-client に依存せず、API ターゲットは Firebase に依存しません。
public struct APITokenProviderAdapter: AuthTokenProvider {
    private let provider: any AuthTokenProviding

    public init(_ provider: any AuthTokenProviding) {
        self.provider = provider
    }

    public func getToken() async throws -> String? {
        await provider.token()
    }
}
