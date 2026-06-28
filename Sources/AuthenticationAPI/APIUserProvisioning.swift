import Foundation
import APIClient
import Authentication

/// REST API を用いたログイン後処理（ユーザープロビジョニング）の具象。
///
/// 認証成功後にバックエンドの初期化エンドポイント（既定 `POST /auth/initialize`）を呼ぶ。
/// サーバ側で冪等であることを前提とする（``AuthenticationStore`` はセッション中 1 回だけ
/// 呼び出す）。
public final class APIUserProvisioning<Client: APIExecutable>: PostAuthenticationAction {
    private let apiClient: Client
    private let path: String

    /// ユーザープロビジョニングアクションを生成する。
    ///
    /// - Parameters:
    ///   - apiClient: リクエストを実行する API クライアント。
    ///   - path: プロビジョニングエンドポイントのパス（省略時は `/auth/initialize`）。
    public init(apiClient: Client, path: String = "/auth/initialize") {
        self.apiClient = apiClient
        self.path = path
    }

    /// バックエンドのプロビジョニングエンドポイントを呼ぶ。
    ///
    /// - Parameter user: プロビジョニング対象のユーザー。
    /// - Throws: API リクエストの失敗エラー。
    public func perform(for user: AuthUser) async throws {
        _ = try await apiClient.execute(UserProvisioningContract(path: path))
    }
}
