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

    func initializeUser() async throws {
        try await apiClient.execute(AuthInitializeContract(path: authenticationPath))
    }
}

/// レスポンスの形はアプリ側の都合で決まるので、ここでは読まない。
/// 固定の DTO を要求すると、バックエンドが返す形を変えた瞬間に
/// デコード失敗＝サインイン不能になる。
struct AuthInitializeContract: APIContract, APIInput {
    typealias Input = Self
    typealias Output = EmptyOutput

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
