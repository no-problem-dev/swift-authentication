import Foundation

/// A credential that could not be linked because another account already owns it.
///
/// Raised as ``AuthError/credentialAlreadyInUse(_:)`` by ``Authenticator/link(with:)``. It
/// means the person already has an account with this provider — typically created on another
/// device — so the account in hand cannot take it over. What to do next is the app's call:
/// signing in to the existing account switches the user id, and whatever the current account
/// held stays behind with it.
///
/// The collision carries the credential that collided. A session server that verifies the
/// provider's token by its signature accepts the same token again, so
/// ``Authenticator/signIn(resolving:)`` signs in to the owning account without showing the
/// provider's sheet a second time. An authenticator that cannot reuse it — the token expired,
/// or its server spends the nonce on first use — throws the collision back, and
/// ``AuthenticationStore/signIn(resolving:)`` acquires a fresh credential instead.
public struct CredentialCollision: Sendable, Equatable {
    /// The credential that collided.
    ///
    /// - Warning: Carries bearer secrets, like any ``AuthCredential``. Do not log it.
    public let credential: AuthCredential

    /// The email address of the account that owns the credential, when the server reported it.
    ///
    /// Useful for telling the person which account they are about to switch to.
    public let email: String?

    /// The provider whose credential collided.
    public var provider: AuthProviderID { credential.provider }

    /// Creates a collision.
    ///
    /// - Parameters:
    ///   - credential: The credential that collided.
    ///   - email: The email address of the owning account, if known.
    public init(credential: AuthCredential, email: String? = nil) {
        self.credential = credential
        self.email = email
    }
}
