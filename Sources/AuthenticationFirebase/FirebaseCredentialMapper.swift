import Foundation
@preconcurrency import FirebaseAuth
import Authentication

/// A credential that cannot be converted into a Firebase credential.
public enum FirebaseAuthenticatorError: Error, Equatable {
    /// The credential is missing a field its provider requires — an Apple credential without
    /// its raw nonce, a Google one without its access token — or its provider is one Firebase
    /// cannot exchange here. Carries the credential's provider.
    case invalidCredential(Authentication.AuthProviderID)
}

/// Converts a neutral credential into the Firebase credential type.
///
/// `FirebaseAuthenticator` uses it for every exchange. It is public for code that calls
/// Firebase directly with one of this package's credentials — reauthentication before a
/// sensitive operation, say — so that code does not keep its own copy of the conversion.
public enum FirebaseCredentialMapper {
    /// Converts a credential produced by `AppleCredentialProvider` or
    /// `GoogleCredentialProvider`.
    ///
    /// - Parameter credential: The neutral credential.
    /// - Returns: `nil` for anonymous sign-in, which has no credential to convert — the
    ///   caller opens an anonymous session instead.
    /// - Throws: ``FirebaseAuthenticatorError/invalidCredential(_:)`` when the credential is
    ///   missing a field its provider requires, such as an Apple credential without its raw
    ///   nonce, or comes from a provider other than Apple, Google or anonymous.
    public static func makeCredential(
        from credential: Authentication.AuthCredential
    ) throws -> FirebaseAuth.AuthCredential? {
        switch credential.provider {
        case .anonymous:
            return nil

        case .apple:
            guard let idToken = credential.idToken, let rawNonce = credential.rawNonce else {
                throw FirebaseAuthenticatorError.invalidCredential(.apple)
            }
            return OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: rawNonce,
                fullName: credential.fullName.map(personNameComponents)
            )

        case .google:
            guard let idToken = credential.idToken, let accessToken = credential.accessToken else {
                throw FirebaseAuthenticatorError.invalidCredential(.google)
            }
            return GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        default:
            throw FirebaseAuthenticatorError.invalidCredential(credential.provider)
        }
    }

    private static func personNameComponents(_ name: PersonName) -> PersonNameComponents {
        var components = PersonNameComponents()
        components.givenName = name.givenName
        components.familyName = name.familyName
        return components
    }
}
