import Foundation

/// The signed-in user, reduced to what the authentication layer can vouch for.
///
/// Deliberately small, so that a provider's own user type never reaches views or use cases.
/// Anything richer — avatars, roles, preferences — belongs to your backend and is fetched
/// separately.
public struct AuthUser: Identifiable, Sendable, Equatable {
    /// The stable, provider-independent user ID, suitable as the foreign key in your backend.
    ///
    /// It survives token refreshes and sign-outs, but a fresh anonymous session gets a new
    /// one, so it is an account identifier and never a device identifier.
    public let id: String

    /// The email address, or `nil` for anonymous sessions and providers that returned none.
    public let email: String?
    /// The display name, or `nil` when the provider did not supply one.
    ///
    /// Often `nil` for Apple, which hands the name over only on the first authorization.
    public let displayName: String?
    /// Whether the session has no provider linked to it.
    ///
    /// An anonymous account is only as durable as the credentials stored on the device, so
    /// prompt for a real provider before anything worth keeping accumulates under it.
    public let isAnonymous: Bool

    /// Every provider linked to the account. Empty while anonymous, and it grows when a
    /// second provider is linked to the same account.
    public let providerIDs: [AuthProviderID]

    public init(
        id: String,
        email: String? = nil,
        displayName: String? = nil,
        isAnonymous: Bool = false,
        providerIDs: [AuthProviderID] = []
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.isAnonymous = isAnonymous
        self.providerIDs = providerIDs
    }
}
