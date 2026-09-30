import Foundation
@preconcurrency import FirebaseAuth
import Authentication

/// Supplies Firebase identity tokens to anything that needs a bearer token.
///
/// Wrap it in `APITokenProviderAdapter` from `AuthenticationAPI` before handing it to a REST
/// client, which is what keeps that client free of any Firebase import. A transport that takes
/// a token closure gets one from `tokenSource`.
public final class FirebaseTokenProvider: AuthTokenProviding, @unchecked Sendable {
    private let auth: Auth

    public init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    /// Returns an identity token for the signed-in user.
    ///
    /// - Parameter forceRefresh: `false` returns Firebase's cached token, which Firebase
    ///   refreshes on its own when it has expired. `true` fetches a new one from Firebase even
    ///   when the cached token has not expired — after the server has answered 401, say, or
    ///   when custom claims changed on the server and the cached token predates them.
    /// - Returns: The token, or `nil` when nobody is signed in.
    /// - Throws: Firebase's error, propagated unchanged. A failed refresh is never turned into
    ///   `nil`, because that would send an unauthenticated request and hide the real cause.
    public func token(forceRefresh: Bool) async throws -> String? {
        guard let user = auth.currentUser else { return nil }
        return try await user.getIDToken(forcingRefresh: forceRefresh)
    }
}
