import Foundation
@preconcurrency import FirebaseAuth
import Authentication

/// Supplies Firebase identity tokens to anything that needs a bearer token.
///
/// Wrap it in `APITokenProviderAdapter` from `AuthenticationAPI` before handing it to a REST
/// client, which is what keeps that client free of any Firebase import.
public final class FirebaseTokenProvider: AuthTokenProviding, @unchecked Sendable {
    private let auth: Auth

    public init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    /// Returns a valid identity token, letting Firebase refresh it when the cached one has
    /// expired.
    ///
    /// - Returns: The token, or `nil` when nobody is signed in.
    /// - Throws: Firebase's error, propagated unchanged. A failed refresh is never turned into
    ///   `nil`, because that would send an unauthenticated request and hide the real cause.
    public func token() async throws -> String? {
        guard let user = auth.currentUser else { return nil }
        return try await user.getIDToken()
    }
}
