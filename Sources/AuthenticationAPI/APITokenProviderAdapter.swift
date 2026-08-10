import Foundation
import APIClient
import Authentication

/// Bridges this package's token abstraction to the one swift-api-client expects.
///
/// The adapter is what keeps the two dependencies apart: the Firebase target never imports
/// swift-api-client and this target never imports Firebase. Wrap a `FirebaseTokenProvider` in
/// one of these to give an API client the source of its `Authorization: Bearer` header.
public struct APITokenProviderAdapter: AuthTokenProvider {
    private let provider: any AuthTokenProviding

    /// Wraps a token provider so an API client can use it.
    ///
    /// - Parameter provider: The token source, for example `FirebaseTokenProvider`.
    public init(_ provider: any AuthTokenProviding) {
        self.provider = provider
    }

    /// Asks the wrapped provider for a token.
    ///
    /// - Returns: A token valid right now, or `nil` when nobody is signed in.
    /// - Throws: Whatever the wrapped provider raised, unchanged — a failed refresh must reach
    ///   the caller rather than turn into a silently unauthenticated request.
    public func fetchToken() async throws -> String? {
        try await provider.token()
    }
}
