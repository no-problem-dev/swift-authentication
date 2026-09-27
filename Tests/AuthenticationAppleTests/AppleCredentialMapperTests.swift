import Testing
import Foundation
import Authentication
@testable import AuthenticationApple

@Suite("AppleCredentialMapper")
struct AppleCredentialMapperTests {
    @Test("carries the identity token, raw nonce and authorization code")
    func mapsAllFields() throws {
        let credential = try #require(AppleCredentialMapper.credential(
            identityToken: Data("header.payload.signature".utf8),
            authorizationCode: Data("c0de".utf8),
            rawNonce: "raw-nonce",
            fullName: nil
        ))
        #expect(credential.provider == .apple)
        #expect(credential.idToken == "header.payload.signature")
        #expect(credential.rawNonce == "raw-nonce")
        #expect(credential.authorizationCode == "c0de")
        #expect(credential.accessToken == nil)
        #expect(credential.fullName == nil)
    }

    @Test("keeps the name Apple returned on the first authorization")
    func mapsFullName() throws {
        var name = PersonNameComponents()
        name.givenName = "Taro"
        name.familyName = "Yamada"
        let credential = try #require(AppleCredentialMapper.credential(
            identityToken: Data("token".utf8),
            authorizationCode: nil,
            rawNonce: "n",
            fullName: name
        ))
        #expect(credential.fullName == PersonName(givenName: "Taro", familyName: "Yamada"))
    }

    @Test("a missing authorization code still yields a credential")
    func missingAuthorizationCode() throws {
        let credential = try #require(AppleCredentialMapper.credential(
            identityToken: Data("token".utf8),
            authorizationCode: nil,
            rawNonce: "n",
            fullName: nil
        ))
        #expect(credential.authorizationCode == nil)
    }

    @Test("an authorization code that is not UTF-8 is dropped, not fatal")
    func undecodableAuthorizationCode() throws {
        let credential = try #require(AppleCredentialMapper.credential(
            identityToken: Data("token".utf8),
            authorizationCode: Data([0xFF, 0xFE]),
            rawNonce: "n",
            fullName: nil
        ))
        #expect(credential.authorizationCode == nil)
    }

    @Test("no identity token means no credential")
    func missingIdentityToken() {
        #expect(AppleCredentialMapper.credential(
            identityToken: nil, authorizationCode: Data("c".utf8), rawNonce: "n", fullName: nil
        ) == nil)
        #expect(AppleCredentialMapper.credential(
            identityToken: Data([0xFF, 0xFE]), authorizationCode: nil, rawNonce: "n", fullName: nil
        ) == nil)
    }

    @Test("the original factory and initializer leave the code nil")
    func sourceCompatibleFactories() {
        #expect(AuthCredential.apple(idToken: "t", rawNonce: "n").authorizationCode == nil)
        #expect(AuthCredential(provider: .apple, idToken: "t").authorizationCode == nil)
        #expect(AuthCredential.anonymous.authorizationCode == nil)
    }

    @Test("the authorization code takes part in equality")
    func equality() {
        let without = AuthCredential.apple(idToken: "t", rawNonce: "n")
        let with = AuthCredential.apple(idToken: "t", rawNonce: "n", authorizationCode: "c")
        #expect(without != with)
        #expect(with == AuthCredential.apple(idToken: "t", rawNonce: "n", authorizationCode: "c"))
    }
}
