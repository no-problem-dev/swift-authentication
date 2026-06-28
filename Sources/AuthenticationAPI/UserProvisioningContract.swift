import Foundation
import APIClient

/// 既定のユーザープロビジョニング応答（`{ "initialized": Bool, "message": String }`）。
public struct UserProvisioningResponse: Decodable, Sendable {
    public let initialized: Bool
    public let message: String

    public init(initialized: Bool, message: String) {
        self.initialized = initialized
        self.message = message
    }
}

/// 既定のユーザープロビジョニング API 契約（`POST <path>`、既定は `/auth/initialize`）。
///
/// swift-api-contract の自己エンコード契約（`Input == Self`）として実装。
/// パスは `init(path:)` で差し替え可能。別レスポンス型が必要なら、独自の
/// `APIContract & APIInput`（`Input == Self`）を定義して ``APIUserProvisioning`` に渡す。
public struct UserProvisioningContract: APIContract, APIInput {
    public typealias Input = Self
    public typealias Output = UserProvisioningResponse

    public static var method: APIMethod { .post }
    public static var subPath: String { "" }

    public let path: String

    public init(path: String = "/auth/initialize") {
        self.path = path
    }

    /// 完全パスは `init(path:)` の値を使う（Group/subPath ではなくインスタンス指定）。
    public static func resolvePath(with input: Self) -> String {
        input.path
    }

    /// クライアント専用契約（サーバ側デコードは未使用）。
    public static func decode(
        pathParameters: [String: String],
        queryParameters: [String: String],
        body: Data?,
        decoder: JSONDecoder
    ) throws -> Self {
        Self(path: "")
    }
}
