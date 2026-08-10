import Foundation
import Authentication

public extension AuthenticationStore {
    /// A store parked in the signed-out state, for previews. Builds without Firebase or any
    /// other SDK.
    static var previewUnauthenticated: AuthenticationStore {
        AuthenticationStore(authenticator: PreviewStubAuthenticator(initial: nil))
    }

    /// A store already signed in as a placeholder user, for previews of screens behind the
    /// sign-in wall.
    static var previewAuthenticated: AuthenticationStore {
        AuthenticationStore(authenticator: PreviewStubAuthenticator(initial: AuthUser(id: "preview-user")))
    }

    /// A store already signed in as the given user, for previews that show profile details.
    ///
    /// - Parameter user: The user the preview should appear to be signed in as.
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
