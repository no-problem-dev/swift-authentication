import Foundation
import APIClient

/// API側での認証確認を行うリポジトリの実装（内部使用）
final class APIAuthRepositoryImpl: APIAuthRepository {
    private let apiClient: any APIClient
    private let authenticationPath: String

    init(apiClient: any APIClient, authenticationPath: String) {
        self.apiClient = apiClient
        self.authenticationPath = authenticationPath
    }

    func initializeUser() async throws -> InitializeUserResult {
        struct ResponseDTO: Decodable {
            let initialized: Bool
            let message: String
        }

        let endpoint = APIEndpoint(
            path: authenticationPath,
            method: .post
        )

        let response: ResponseDTO = try await apiClient.request(endpoint)
        return InitializeUserResult(
            initialized: response.initialized,
            message: response.message
        )
    }
}
