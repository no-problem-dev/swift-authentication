import Testing
import Foundation
@testable import Authentication

/// Errors and values end up in logs and crash reports through `String(describing:)`, string
/// interpolation and `dump`. None of them may carry a token.
@Suite("Secret redaction")
struct SecretRedactionTests {
    private let sample = AuthCredential(
        provider: .apple,
        idToken: "SECRET-ID-TOKEN",
        accessToken: "SECRET-ACCESS-TOKEN",
        rawNonce: "SECRET-NONCE",
        fullName: nil,
        authorizationCode: "SECRET-CODE"
    )

    private func renderings(_ value: Any) -> [String] {
        var dumped = ""
        dump(value, to: &dumped)
        return [String(describing: value), String(reflecting: value), "\(value)", dumped]
    }

    @Test("a credential prints its provider and none of its secrets")
    func credential() {
        for text in renderings(sample) {
            #expect(!text.contains("SECRET"), "\(text)")
            #expect(text.contains("apple"))
        }
    }

    @Test("a collision error does not print the credential it carries")
    func collisionError() {
        let error = AuthError.credentialAlreadyInUse(CredentialCollision(credential: sample, email: nil))
        for text in renderings(error) + [(error as NSError).description, error.localizedDescription] {
            #expect(!text.contains("SECRET"), "\(text)")
        }
    }

    @Test("a legacy credential prints its kind and not the token")
    func legacyCredential() {
        for value in [LegacyCredential.firebaseRefreshToken("SECRET-REFRESH"), .firebaseIDToken("SECRET-ID")] {
            for text in renderings(value) {
                #expect(!text.contains("SECRET"), "\(text)")
                #expect(text.contains("firebase"))
            }
        }
    }
}
