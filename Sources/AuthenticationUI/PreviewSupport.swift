import Foundation
import Authentication

public extension AuthenticationStore {
    static var previewUnauthenticated: AuthenticationStore {
        AuthenticationStore(authenticator: PreviewStubAuthenticator(initial: nil))
    }

    static var previewAuthenticated: AuthenticationStore {
        AuthenticationStore(authenticator: PreviewStubAuthenticator(initial: AuthUser(id: "preview-user")))
    }

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
