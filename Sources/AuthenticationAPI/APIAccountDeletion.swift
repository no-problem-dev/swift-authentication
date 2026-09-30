import Foundation
import APIClient
import APIContract
import Authentication

/// Deletes the account through the app's REST backend: one `DELETE` that removes the user's
/// data and their authentication account together.
///
/// Hand it to `FirebaseAuthenticator(accountDeletion:)`. The authenticator calls it from
/// `deleteAccount()` and clears the local session only once it succeeds, so a failed request
/// can be retried with the bearer token still in hand.
///
/// ```swift
/// let authenticator = FirebaseAuthenticator(
///     accountDeletion: APIAccountDeletion(apiClient: apiClient, path: "/v1/me")
/// )
/// ```
///
/// What the endpoint has to do for this to be safe: delete the app's data first and the
/// authentication account last, so that if it fails midway the caller can still authenticate
/// and retry; and answer success when the account is already gone, so a retry after a lost
/// response converges instead of failing forever.
public final class APIAccountDeletion<Client: APIExecutable>: AccountDeletion {
    private let apiClient: Client
    private let path: String

    /// Creates the deletion.
    ///
    /// - Parameters:
    ///   - apiClient: The client that performs the request, already carrying the token
    ///     provider so the call is authenticated.
    ///   - path: The deletion endpoint, for example `/v1/me`. No default: unlike provisioning
    ///     there is no convention common enough to guess at, and a wrong guess deletes nothing
    ///     while the app reports that it did.
    public init(apiClient: Client, path: String) {
        self.apiClient = apiClient
        self.path = path
    }

    /// Sends the deletion request.
    ///
    /// - Parameter user: The signed-in user. Not sent — the backend identifies the caller from
    ///   the bearer token.
    /// - Throws: ``AuthError/sessionExpired(_:)`` for a 401, ``AuthError/notPermitted(_:)`` for
    ///   a 403, and whatever the API client raised for anything else.
    public func deleteAccount(of user: AuthUser) async throws {
        do {
            try await apiClient.execute(AccountDeletionContract(path: path))
        } catch let error as APIError {
            switch error {
            case .unauthorized: throw AuthError.sessionExpired(error)
            case .forbidden: throw AuthError.notPermitted(error)
            default: throw error
            }
        }
    }
}

/// The request ``APIAccountDeletion`` sends: a `DELETE` to a caller-chosen path.
///
/// Shaped like ``UserProvisioningContract``: the path belongs to the instance, and the
/// response body is left unread because only success or failure carries meaning.
public struct AccountDeletionContract: APIContract, APIInput {
    public typealias Input = Self
    public typealias Output = EmptyOutput

    public static var method: APIMethod { .delete }
    public static var subPath: String { "" }

    public let path: String

    public init(path: String) {
        self.path = path
    }

    /// Returns the path carried by the instance, ignoring the group and sub-path the protocol
    /// would otherwise assemble.
    public static func resolvePath(with input: Self) -> String {
        input.path
    }

    /// Never used: this contract is only ever sent.
    public static func decode(
        pathParameters: [String: String],
        queryParameters: [String: String],
        body: Data?,
        decoder: any APIBodyDecoder
    ) throws -> Self {
        Self(path: "")
    }
}
