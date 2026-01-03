import Foundation
import APIClient

/// API認証リポジトリ実装
final class APIAuthRepositoryImpl<Client: APIExecutable>: APIAuthRepository {
    private let apiClient: Client
    private let authenticationPath: String

    init(apiClient: Client, authenticationPath: String) {
        self.apiClient = apiClient
        self.authenticationPath = authenticationPath
    }

    func initializeUser() async throws -> InitializeUserResult {
        let response: AuthInitializeResponse = try await apiClient.execute(
            AuthInitializeContract(path: authenticationPath)
        )
        return InitializeUserResult(
            initialized: response.initialized,
            message: response.message
        )
    }
}

struct AuthInitializeContract: APIContract, APIInput {
    typealias Input = Self
    typealias Output = AuthInitializeResponse

    static let method: APIMethod = .post
    static let subPath: String = ""

    let path: String

    var pathParameters: [String: String] { [:] }
    var queryParameters: [String: String]? { nil }

    func encodeBody(using encoder: JSONEncoder) throws -> Data? { nil }

    static func resolvePath(with input: Self) -> String {
        input.path
    }

    static func decode(
        pathParameters: [String: String],
        queryParameters: [String: String],
        body: Data?,
        decoder: JSONDecoder
    ) throws -> Self {
        fatalError("Client-only contract")
    }
}

struct AuthInitializeResponse: Decodable, Sendable {
    let initialized: Bool
    let message: String
}
