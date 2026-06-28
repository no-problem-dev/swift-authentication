import Foundation

/// 資格情報の取得（取得層）。
///
/// Apple / Google などのインタラクティブな UI フローを起動し、
/// vendor 非依存な ``AuthCredential`` を生成する責務を持つ。
/// 具象は `AuthenticationApple` / `AuthenticationGoogle` ターゲットで実装。
public protocol CredentialProvider: Sendable {
    /// このプロバイダが扱うプロバイダ識別子。
    var providerID: AuthProviderID { get }

    /// 資格情報を取得する。ユーザーがキャンセルした場合は ``AuthError/cancelled`` を投げる。
    func acquireCredential() async throws -> AuthCredential
}
