import Foundation

/// Supplies the current authentication token to code that must not know where it came from.
///
/// This is the seam that lets a REST client send `Authorization: Bearer` without importing an
/// authentication SDK. `AuthenticationFirebase` conforms with `FirebaseTokenProvider`, and
/// `AuthenticationAPI` bridges that to swift-api-client with `APITokenProviderAdapter`.
public protocol AuthTokenProviding: Sendable {
    /// Returns a token that is valid right now, refreshing it if the stored one has expired.
    ///
    /// - Returns: The token, or `nil` when nobody is signed in.
    /// - Throws: Whatever the refresh raised. A failed refresh must never be reported as
    ///   `nil`, or the caller sends an unauthenticated request and sees a puzzling rejection
    ///   instead of the real error.
    func token() async throws -> String?
}
