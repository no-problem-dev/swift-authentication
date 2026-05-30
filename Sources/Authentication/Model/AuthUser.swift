import Foundation

/// 認証済みユーザーを表す vendor 非依存な値型。
///
/// Firebase の `User` 型を漏らさないため、必要最小限の属性のみを保持します。
/// 詳細なプロフィールはバックエンド API 等から別途取得する設計です。
public struct AuthUser: Identifiable, Sendable, Equatable {
    /// プロバイダ非依存の一意な ID（Firebase の uid など）。
    public let id: String

    public let email: String?
    public let displayName: String?
    public let isAnonymous: Bool

    /// このユーザーが連携しているプロバイダ一覧。
    public let providerIDs: [AuthProviderID]

    public init(
        id: String,
        email: String? = nil,
        displayName: String? = nil,
        isAnonymous: Bool = false,
        providerIDs: [AuthProviderID] = []
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.isAnonymous = isAnonymous
        self.providerIDs = providerIDs
    }
}
