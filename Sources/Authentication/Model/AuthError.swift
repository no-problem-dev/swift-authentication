import Foundation

/// A failure somewhere in the sign-in flow, carrying the error that caused it.
///
/// The type stays vendor-neutral while the originating error — from the session server or GoogleSignIn,
/// say — travels as an associated value, so callers can inspect the cause without the core
/// importing that SDK. Those payloads are `any Error`, which is why this enum is not
/// `Equatable`; compare ``code`` instead.
public enum AuthError: Error {
    /// The user dismissed the provider's sign-in sheet. An ordinary outcome — swallow it
    /// rather than presenting it as a failure.
    case cancelled
    /// Sign-in was requested for a provider that was never registered with the store.
    /// A wiring mistake at the composition root, not a runtime condition.
    case unsupportedProvider(AuthProviderID)
    /// The provider's interactive flow failed before producing a token. Nothing was sent to
    /// the authentication server.
    case credentialAcquisitionFailed(any Error)
    /// The authentication server rejected the credential or could not be reached. No session
    /// exists afterwards.
    case sessionExchangeFailed(any Error)
    /// The server rejected the session itself — a 401 that a refresh did not fix. Signing in
    /// again is what fixes it.
    ///
    /// For an app's API client to raise: the token was stale, revoked, or belongs to a disabled
    /// account. Which of those it was does not change the response: obtain a new session.
    ///
    /// Distinct from ``notPermitted(_:)``, where a new session changes nothing.
    case sessionExpired(any Error)
    /// The server accepted the session and refused the operation anyway — a 403. For an app's
    /// API client to raise.
    ///
    /// The account may not do this: a missing scope, a plan limit, a suspension. Signing out
    /// and back in produces the same refusal, so a flow that responds to it by
    /// re-authenticating loops. Report what the server said instead; the payload carries it.
    case notPermitted(any Error)
    /// Clearing the local session failed, which means stored credentials may still be on the
    /// device.
    case signOutFailed(any Error)
    /// Account deletion failed and the account still exists — the deletion request did not
    /// succeed, or the person backed out of the Apple authorization deletion needs.
    case deleteAccountFailed(any Error)
    /// The credential could not be linked because another account already owns it.
    ///
    /// The current session is untouched. The payload says which provider collided and carries
    /// what is needed to sign in to the owning account instead — see ``CredentialCollision``
    /// for why the credential that collided must not be exchanged again.
    case credentialAlreadyInUse(CredentialCollision)
    /// Linking a credential to the current account failed for any other reason — the provider
    /// is already linked, the credential was rejected, the server could not be reached. The
    /// current session is untouched.
    case linkFailed(any Error)
    /// The credential's email address already belongs to an account that signs in with a
    /// different provider, and the server keeps one account per email address.
    ///
    /// Raised by linking and by signing in, with the current session untouched. Unlike
    /// ``credentialAlreadyInUse(_:)`` there is no account this credential can switch to: the
    /// person has to sign in with the provider that account already uses. `provider` is the
    /// one that was attempted, and `email` the address the server reported, when it did — show
    /// it so the person knows which account is meant.
    case accountExistsWithDifferentProvider(provider: AuthProviderID, email: String?)
    /// The account was deleted. Signing in to it again is not possible; start a new one.
    ///
    /// The server answers 410 for a deleted account's tokens, and when a credential or an
    /// earlier session that belonged to it is exchanged.
    case accountDeleted
    /// An operation that needs a signed-in user was requested while there was none.
    case notAuthenticated
    /// Required setup is missing or wrong — an unset client ID, no window to present from.
    /// The payload says which.
    case configuration(String)
}

extension AuthError {
    /// The kind of a failure, stripped of its payload so it can be compared.
    public enum Code: Equatable, Sendable {
        case cancelled
        case unsupportedProvider
        case credentialAcquisitionFailed
        case sessionExchangeFailed
        case sessionExpired
        case notPermitted
        case signOutFailed
        case deleteAccountFailed
        case credentialAlreadyInUse
        case linkFailed
        case accountExistsWithDifferentProvider
        case accountDeleted
        case notAuthenticated
        case configuration
    }

    /// The kind of this failure, without the underlying error.
    ///
    /// Use it to branch or assert without pattern-matching every case — the payloads make the
    /// enum itself uncomparable.
    public var code: Code {
        switch self {
        case .cancelled: .cancelled
        case .unsupportedProvider: .unsupportedProvider
        case .credentialAcquisitionFailed: .credentialAcquisitionFailed
        case .sessionExchangeFailed: .sessionExchangeFailed
        case .sessionExpired: .sessionExpired
        case .notPermitted: .notPermitted
        case .signOutFailed: .signOutFailed
        case .deleteAccountFailed: .deleteAccountFailed
        case .credentialAlreadyInUse: .credentialAlreadyInUse
        case .linkFailed: .linkFailed
        case .accountExistsWithDifferentProvider: .accountExistsWithDifferentProvider
        case .accountDeleted: .accountDeleted
        case .notAuthenticated: .notAuthenticated
        case .configuration: .configuration
        }
    }
}
