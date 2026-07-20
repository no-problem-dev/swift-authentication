import Foundation
import APIClient

/// 既定のユーザープロビジョニング API 契約（`POST <path>`、既定は `/auth/initialize`）。
///
/// swift-api-contract の自己エンコード契約（`Input == Self`）として実装。
/// パスは `init(path:)` で差し替え可能。
///
/// レスポンスの本文は読まない（``EmptyOutput``）。プロビジョニングの結果として
/// このパッケージが使うのは成否だけで、本文の形はアプリごとに違う。固定の DTO を
/// 要求すると、バックエンドが形を変えた瞬間にデコード失敗＝サインイン不能になる。
public struct UserProvisioningContract: APIContract, APIInput {
    public typealias Input = Self
    public typealias Output = EmptyOutput

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
        decoder: any APIBodyDecoder
    ) throws -> Self {
        Self(path: "")
    }
}
