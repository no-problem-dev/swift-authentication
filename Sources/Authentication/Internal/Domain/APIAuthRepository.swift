import Foundation

/// API認証リポジトリプロトコル
protocol APIAuthRepository: Sendable {
    /// サインイン直後にバックエンド側の初期化を促す。
    /// レスポンスの中身はアプリごとに違うので、ここでは成否だけを見る。
    func initializeUser() async throws
}
