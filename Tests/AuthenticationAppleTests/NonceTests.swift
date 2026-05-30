import Testing
import Foundation
@testable import AuthenticationApple

@Suite("Nonce")
struct NonceTests {
    @Test("random nonce has the requested length")
    func randomLength() {
        #expect(Nonce.randomNonceString(length: 32).count == 32)
        #expect(Nonce.randomNonceString(length: 16).count == 16)
    }

    @Test("random nonce only uses the allowed charset")
    func randomCharset() {
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = Nonce.randomNonceString(length: 200)
        #expect(nonce.allSatisfy { allowed.contains($0) })
    }

    @Test("sha256 matches the known vector and is lowercase hex")
    func sha256Vector() {
        // SHA256("abc")
        #expect(Nonce.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(Nonce.sha256("abc").count == 64)
    }
}
