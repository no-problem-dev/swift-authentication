import Foundation

/// API認証リポジトリプロトコル
protocol APIAuthRepository: Sendable {
    func initializeUser() async throws -> InitializeUserResult
}

struct InitializeUserResult: Sendable {
    let initialized: Bool
    let message: String
}
