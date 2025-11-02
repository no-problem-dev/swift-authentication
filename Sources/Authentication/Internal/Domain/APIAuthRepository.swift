import Foundation

/// API側での認証確認を行うリポジトリプロトコル（内部使用）
protocol APIAuthRepository: Sendable {
    /// ユーザーの初期化
    func initializeUser() async throws -> InitializeUserResult
}

// MARK: - Results

struct InitializeUserResult: Sendable {
    let initialized: Bool
    let message: String
}
