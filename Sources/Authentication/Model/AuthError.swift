import Foundation

/// A failure somewhere in the sign-in flow, carrying the error that caused it.
///
/// The type stays vendor-neutral while the originating error — from Firebase or GoogleSignIn,
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
    /// The session was established but the post-authentication work failed, leaving the user
    /// signed in on the server and unprovisioned in the app.
    case postAuthenticationFailed(any Error)
    /// Clearing the local session failed, which means stored credentials may still be on the
    /// device.
    case signOutFailed(any Error)
    /// Account deletion failed and the account still exists. Providers commonly refuse when
    /// the last sign-in is too old.
    case deleteAccountFailed(any Error)
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
        case postAuthenticationFailed
        case signOutFailed
        case deleteAccountFailed
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
        case .postAuthenticationFailed: .postAuthenticationFailed
        case .signOutFailed: .signOutFailed
        case .deleteAccountFailed: .deleteAccountFailed
        case .notAuthenticated: .notAuthenticated
        case .configuration: .configuration
        }
    }
}
