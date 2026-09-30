import Foundation

/// Supplies the current authentication token to code that must not know where it came from.
///
/// This is the seam that lets a REST client send `Authorization: Bearer` without importing an
/// authentication SDK. `AuthenticationFirebase` conforms with `FirebaseTokenProvider`, and
/// `AuthenticationAPI` bridges that to swift-api-client with `APITokenProviderAdapter`.
///
/// There is one requirement and no default for it. A conformance that could not refresh on
/// demand would have to answer `forceRefresh: true` with the token it already holds, and the
/// caller — retrying after a 401 — would send the same rejected token again believing it new.
public protocol AuthTokenProviding: Sendable {
    /// Returns a token for the signed-in user.
    ///
    /// - Parameter forceRefresh: `false` returns the stored token, refreshing it only when it
    ///   has expired. `true` obtains a new one from the server even if the stored token has not
    ///   expired yet — what to do after the server has rejected the stored one with a 401.
    /// - Returns: The token, or `nil` when nobody is signed in.
    /// - Throws: Whatever the refresh raised. A failed refresh must never be reported as
    ///   `nil`, or the caller sends an unauthenticated request and sees a puzzling rejection
    ///   instead of the real error.
    func token(forceRefresh: Bool) async throws -> String?
}

extension AuthTokenProviding {
    /// Returns the stored token, refreshing it only when it has expired.
    ///
    /// Shorthand for `token(forceRefresh: false)`.
    public func token() async throws -> String? {
        try await token(forceRefresh: false)
    }

    /// Returns a token, treating "nobody is signed in" as a failure rather than as `nil`.
    ///
    /// For callers that cannot send a request without a token, such as an authorization
    /// middleware.
    ///
    /// - Parameter forceRefresh: As for ``token(forceRefresh:)``.
    /// - Throws: ``AuthError/notAuthenticated`` when nobody is signed in, and whatever the
    ///   refresh raised otherwise.
    public func requiredToken(forceRefresh: Bool = false) async throws -> String {
        guard let token = try await token(forceRefresh: forceRefresh) else {
            throw AuthError.notAuthenticated
        }
        return token
    }

    /// This provider as a closure, in the shape transports that take a token source expect.
    ///
    /// ```swift
    /// let token: @Sendable (_ forceRefresh: Bool) async throws -> String =
    ///     FirebaseTokenProvider().tokenSource
    /// ```
    ///
    /// Calls ``requiredToken(forceRefresh:)``, so a signed-out call throws
    /// ``AuthError/notAuthenticated`` instead of producing a request without a token.
    public var tokenSource: @Sendable (_ forceRefresh: Bool) async throws -> String {
        { forceRefresh in try await self.requiredToken(forceRefresh: forceRefresh) }
    }
}
