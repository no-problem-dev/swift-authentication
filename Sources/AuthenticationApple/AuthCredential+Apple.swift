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
}
