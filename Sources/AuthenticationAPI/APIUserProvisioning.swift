import Foundation
import APIClient
import Authentication

/// REST API を用いたログイン後処理（ユーザープロビジョニング）の具象。
///
/// 認証成功後にバックエンドの初期化エンドポイント（既定 `POST /auth/initialize`）を呼びます。
/// サーバ側で冪等であることを前提とします（``AuthenticationStore`` はセッション中 1 回だけ
/// 呼び出します）。
public final class APIUserProvisioning<Client: APIExecutable>: PostAuthenticationAction {
    private let apiClient: Client
    private let path: String

    public init(apiClient: Client, path: String = "/auth/initialize") {
        self.apiClient = apiClient
        self.path = path
    }

    public func perform(for user: AuthUser) async throws {
        _ = try await apiClient.execute(UserProvisioningContract(path: path))
    }
}
