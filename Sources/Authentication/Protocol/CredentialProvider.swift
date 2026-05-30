import Foundation

/// 資格情報の取得（取得層）。
///
/// Apple / Google などのインタラクティブな UI フローを起動し、
/// vendor 非依存な ``AuthCredential`` を生成する責務を持ちます。
/// 具象は `AuthenticationApple` / `AuthenticationGoogle` ターゲットで実装します。
public protocol CredentialProvider: Sendable {
    /// このプロバイダが扱うプロバイダ識別子。
    var providerID: AuthProviderID { get }

    /// 資格情報を取得します。ユーザーがキャンセルした場合は ``AuthError/cancelled`` を投げます。
    func acquireCredential() async throws -> AuthCredential
}
