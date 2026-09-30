import Foundation

/// A credential that could not be linked because another account already owns it.
///
/// Raised as ``AuthError/credentialAlreadyInUse(_:)`` by ``Authenticator/link(with:)``. It
/// means the person already has an account with this provider — typically created on another
/// device — so the anonymous account in hand cannot take it over. What to do next is the
/// app's call: signing in to the existing account switches the user id, and whatever the
/// anonymous account held stays behind with it.
///
/// **Never retry with the credential that collided.** An Apple identity token embeds a nonce
/// the server accepts once; the link spent it, so exchanging the same token again fails with
/// a "duplicate credential" error. Google tokens happen to survive a second use, which is what
/// makes reuse look fine until someone signs in with Apple. Resume through
/// ``Authenticator/signIn(resolving:)`` or ``AuthenticationStore/signIn(resolving:)`` instead:
/// they use the replacement the server issued with the rejection, and the store falls back to
/// acquiring a fresh credential from the provider when there is none.
public struct CredentialCollision: Sendable {
    /// The provider whose credential collided.
    public let provider: AuthProviderID

    /// The email address of the account that owns the credential, when the server reported it.
    ///
    /// Useful for telling the person which account they are about to switch to.
    public let email: String?

    /// A replacement credential the server issued with the rejection, in the authenticator's
    /// own representation, or `nil` when it issued none.
    ///
    /// Opaque on purpose: only the ``Authenticator`` that raised the collision can read it,
    /// through ``Authenticator/signIn(resolving:)``.
    public let renewedCredential: (any Sendable)?

    /// Creates a collision.
    ///
    /// - Parameters:
    ///   - provider: The provider whose credential collided.
    ///   - email: The email address of the owning account, if known.
    ///   - renewedCredential: A replacement credential the server issued, in the
    ///     authenticator's own representation. `nil` when there is none.
    public init(provider: AuthProviderID, email: String? = nil, renewedCredential: (any Sendable)? = nil) {
        self.provider = provider
        self.email = email
        self.renewedCredential = renewedCredential
    }
}
