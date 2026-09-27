import Foundation

/// Proof of identity that the authentication server trades for a session.
///
/// A neutral value that never mentions a provider SDK type, such as Firebase's own
/// credential type. A ``CredentialProvider`` produces one, an ``Authenticator`` spends it.
///
/// Build one through the factory that ships with the provider's target — for example
/// `AuthCredential.apple(idToken:rawNonce:fullName:)` — rather than by hand, since each
/// provider populates a different subset of the fields below.
///
/// - Warning: The token fields are bearer secrets for as long as they are valid. Do not log
///   an instance of this type or write it to disk.
public struct AuthCredential: Sendable, Equatable {
    /// The provider this credential came from, which decides how it is exchanged and which
    /// of the fields below are populated.
    public let provider: AuthProviderID

    /// The OIDC identity token issued by Apple or Google; `nil` for anonymous sign-in.
    public let idToken: String?

    /// The OAuth access token, which only Google supplies; `nil` for Apple and anonymous.
    public let accessToken: String?

    /// The unhashed nonce that was sent, in SHA-256 form, with the Apple authorization request.
    ///
    /// The server matches it against the nonce claim inside the identity token, which is what
    /// makes a captured token useless in a replay. Put the raw value here, never the hash.
    /// `nil` outside the Apple flow.
    public let rawNonce: String?

    /// The user's name, which Apple returns only on the first authorization.
    ///
    /// Persist it during that first sign-in. Every later sign-in with the same Apple ID
    /// leaves it `nil`, and there is no way to ask for it again.
    public let fullName: PersonName?

    /// The short-lived authorization code Apple returns alongside the identity token.
    ///
    /// Signing in does not need it. It exists for revoking the user's Sign in with Apple
    /// tokens when they delete their account, which App Review requires (guideline
    /// 5.1.1(v)); with Firebase that is `FirebaseAuthenticator.revokeAppleToken(authorizationCode:)`.
    /// Apple lets the code be redeemed once and only for about five minutes, so obtain a fresh
    /// one immediately before deleting rather than keeping the one from sign-in. `nil` outside
    /// the Apple flow, and when Apple did not supply one.
    public let authorizationCode: String?

    public init(
        provider: AuthProviderID,
        idToken: String? = nil,
        accessToken: String? = nil,
        rawNonce: String? = nil,
        fullName: PersonName? = nil
    ) {
        self.provider = provider
        self.idToken = idToken
        self.accessToken = accessToken
        self.rawNonce = rawNonce
        self.fullName = fullName
        self.authorizationCode = nil
    }

    /// Creates a credential that also carries an Apple authorization code.
    ///
    /// A separate initializer rather than one more defaulted parameter on the one above, so
    /// that initializer keeps its exact signature and existing callers are unaffected.
    public init(
        provider: AuthProviderID,
        idToken: String? = nil,
        accessToken: String? = nil,
        rawNonce: String? = nil,
        fullName: PersonName? = nil,
        authorizationCode: String?
    ) {
        self.provider = provider
        self.idToken = idToken
        self.accessToken = accessToken
        self.rawNonce = rawNonce
        self.fullName = fullName
        self.authorizationCode = authorizationCode
    }

    /// A credential that asks for an anonymous session and carries no tokens.
    public static let anonymous = AuthCredential(provider: .anonymous)
}
