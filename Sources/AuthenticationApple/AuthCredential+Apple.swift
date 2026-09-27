import Foundation
import Authentication

public extension AuthCredential {
    /// Builds a credential from what an Apple authorization returned.
    ///
    /// - Parameters:
    ///   - idToken: The identity token, as the JWT string Apple provided.
    ///   - rawNonce: The nonce before hashing — not the SHA-256 that went on the request.
    ///     The server compares it with the token's nonce claim to rule out a replay.
    ///   - fullName: The name, which Apple returns only on the first authorization.
    static func apple(
        idToken: String,
        rawNonce: String,
        fullName: PersonName? = nil
    ) -> AuthCredential {
        AuthCredential(
            provider: .apple,
            idToken: idToken,
            accessToken: nil,
            rawNonce: rawNonce,
            fullName: fullName
        )
    }

    /// Builds a credential from what an Apple authorization returned, including the
    /// authorization code needed to revoke the user's tokens on account deletion.
    ///
    /// - Parameters:
    ///   - idToken: The identity token, as the JWT string Apple provided.
    ///   - rawNonce: The nonce before hashing — not the SHA-256 that went on the request.
    ///   - fullName: The name, which Apple returns only on the first authorization.
    ///   - authorizationCode: The authorization code, as the string Apple provided. Single use
    ///     and valid for about five minutes.
    static func apple(
        idToken: String,
        rawNonce: String,
        fullName: PersonName? = nil,
        authorizationCode: String?
    ) -> AuthCredential {
        AuthCredential(
            provider: .apple,
            idToken: idToken,
            accessToken: nil,
            rawNonce: rawNonce,
            fullName: fullName,
            authorizationCode: authorizationCode
        )
    }
}

/// Turns the raw fields of an `ASAuthorizationAppleIDCredential` into an `AuthCredential`.
///
/// Kept apart from the delegate callback because the AuthenticationServices types cannot be
/// constructed outside a real authorization, while plain `Data` can — this is the part tests
/// exercise.
enum AppleCredentialMapper {
    /// - Returns: The credential, or `nil` when the identity token is missing or not UTF-8,
    ///   since there is nothing to sign in with. A missing or undecodable authorization code
    ///   only leaves ``AuthCredential/authorizationCode`` `nil`: sign-in does not need it.
    static func credential(
        identityToken: Data?,
        authorizationCode: Data?,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) -> AuthCredential? {
        guard let identityToken, let idToken = String(data: identityToken, encoding: .utf8) else {
            return nil
        }
        return .apple(
            idToken: idToken,
            rawNonce: rawNonce,
            fullName: PersonName(components: fullName),
            authorizationCode: authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        )
    }
}
