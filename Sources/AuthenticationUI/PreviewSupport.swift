import Foundation
import Authentication

public extension AuthenticationStore {
    /// 未認証状態のスタブ。SwiftUI プレビュー用。Firebase 等の SDK 不要で生成できる。
    static var previewUnauthenticated: AuthenticationStore {
        AuthenticationStore(authenticator: PreviewStubAuthenticator(initial: nil))
    }

    /// `id: "preview-user"` で認証済み状態のスタブ。SwiftUI プレビュー用。
    static var previewAuthenticated: AuthenticationStore {
        AuthenticationStore(authenticator: PreviewStubAuthenticator(initial: AuthUser(id: "preview-user")))
    }

    /// 指定ユーザーで認証済み状態のスタブ。SwiftUI プレビュー用。
    static func preview(user: AuthUser) -> AuthenticationStore {
        AuthenticationStore(authenticator: PreviewStubAuthenticator(initial: user))
    }
}

final class PreviewStubAuthenticator: Authenticator, @unchecked Sendable {
    private let initial: AuthUser?

    init(initial: AuthUser?) {
        self.initial = initial
    }

    func currentUser() async -> AuthUser? { initial }

    func signIn(with credential: AuthCredential) async throws -> AuthUser {
        initial ?? AuthUser(id: "preview-user")
    }

    func signOut() async throws {}
    func deleteAccount() async throws {}

    func authStateChanges() -> AsyncStream<AuthUser?> {
        let initial = self.initial
        return AsyncStream { continuation in
            continuation.yield(initial)
        }
    }
}
