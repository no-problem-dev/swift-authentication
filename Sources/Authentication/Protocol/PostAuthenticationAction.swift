import Foundation

/// ログイン後処理（post-auth 層）。
///
/// 認証サーバへのログインが完了した後に実行する処理（ユーザーの初期化・
/// プロビジョニングなど）を表すドメイン概念です。具象は別ターゲット
/// （例: `AuthenticationAPI` の `APIUserProvisioning`）で差し込みます。
///
/// - Important: ``AuthenticationStore`` は認証セッション中に同一ユーザーへ
///   一度だけ ``perform(for:)`` を呼びますが、ネットワーク再試行やプロセス
///   再起動に備え、サーバ側でも冪等であることを前提とします。
public protocol PostAuthenticationAction: Sendable {
    /// ログイン後処理を実行します。
    ///
    /// - Parameter user: 認証済みユーザー。
    /// - Throws: 処理が失敗した場合はエラーを投げます。``AuthenticationStore`` は
    ///   このエラーを ``AuthError/postAuthenticationFailed(_:)`` でラップします。
    func perform(for user: AuthUser) async throws
}

/// 何もしないログイン後処理。プロビジョニング不要なアプリ向けの既定値。
public struct NoPostAuthentication: PostAuthenticationAction {
    public init() {}
    public func perform(for user: AuthUser) async throws {}
}

/// 複数のログイン後処理を順次実行する合成アクション。
public struct CompositePostAuthentication: PostAuthenticationAction {
    private let actions: [any PostAuthenticationAction]

    public init(_ actions: [any PostAuthenticationAction]) {
        self.actions = actions
    }

    public func perform(for user: AuthUser) async throws {
        for action in actions {
            try await action.perform(for: user)
        }
    }
}
