import Foundation

/// The acquisition layer: runs a provider's interactive sign-in and returns a neutral credential.
///
/// Conformances present system UI — the Apple authorization sheet, the Google consent
/// screen — so a call lasts as long as the user takes and can end in cancellation.
/// `AuthenticationApple` and `AuthenticationGoogle` supply the conformances that ship here.
public protocol CredentialProvider: Sendable {
    /// The provider this instance handles.
    ///
    /// ``AuthenticationStore`` keys its registry on the value, so two providers reporting the
    /// same identifier collapse into one.
    var providerID: AuthProviderID { get }

    /// Presents the provider's sign-in UI and returns the credential it produced.
    ///
    /// - Throws: ``AuthError/cancelled`` when the user dismisses the sheet, which is an
    ///   ordinary outcome and not something to surface as an error.
    func acquireCredential() async throws -> AuthCredential
}
