import Foundation
@preconcurrency import FirebaseAuth
import Authentication

enum FirebaseAuthenticatorError: Error {
    case invalidCredential(Authentication.AuthProviderID)
}

/// Converts a neutral credential into the Firebase credential type.
enum FirebaseCredentialMapper {
    /// - Returns: `nil` for anonymous sign-in, which has no credential to convert — the
    ///   caller opens an anonymous session instead.
    /// - Throws: When the credential is missing a field its provider requires, such as an
    ///   Apple credential without its raw nonce.
    static func makeCredential(
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
