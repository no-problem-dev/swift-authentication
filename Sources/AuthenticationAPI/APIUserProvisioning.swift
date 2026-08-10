import Foundation
import APIClient
import Authentication

/// Provisions the user against a REST backend once sign-in succeeds.
///
/// It posts to an initialization endpoint — `/auth/initialize` unless you say otherwise — with
/// the signed-in user's token attached by the API client. `AuthenticationStore` calls it
/// once per session, but retries and reinstalls mean the endpoint itself must be idempotent.
public final class APIUserProvisioning<Client: APIExecutable>: PostAuthenticationAction {
    private let apiClient: Client
    private let path: String

    /// Creates the action.
    ///
    /// - Parameters:
    ///   - apiClient: The client that performs the request, already carrying the token
    ///     provider so the call is authenticated.
    ///   - path: The provisioning endpoint. Defaults to `/auth/initialize`.
    public init(apiClient: Client, path: String = "/auth/initialize") {
        self.apiClient = apiClient
        self.path = path
    }

    /// Calls the backend's provisioning endpoint.
    ///
    /// The response body is never read; only success or failure carries meaning, for the
    /// reason spelled out on ``UserProvisioningContract``.
    ///
    /// - Parameter user: The user that was just signed in. It is not sent in the request —
    ///   the backend identifies the caller from the bearer token.
    /// - Throws: Whatever the API client raised for the request.
    public func perform(for user: AuthUser) async throws {
        try await apiClient.execute(UserProvisioningContract(path: path))
    }
}
