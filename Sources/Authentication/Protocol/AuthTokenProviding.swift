import Foundation

/// 認証トークンを供給する vendor 非依存な抽象。
///
/// REST クライアント等へ ID トークンを渡すための境界。Firebase 実装は
/// `AuthenticationFirebase` の `FirebaseTokenProvider`、swift-api-client への
/// 橋渡しは `AuthenticationAPI` の `APITokenProviderAdapter` が担当する。
public protocol AuthTokenProviding: Sendable {
    /// 現在の認証トークン。未認証なら `nil`。
    func token() async -> String?
}
