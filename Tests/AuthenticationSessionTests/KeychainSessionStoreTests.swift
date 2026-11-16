import Testing
import Foundation
import Security
@testable import AuthenticationSession

@Suite("KeychainSessionStore")
struct KeychainSessionStoreTests {
    @Test("an item that is not a session is reported, left in place, and removed by clear()")
    func undecodableItemIsReportedNotRemoved() throws {
        let service = "AuthenticationSessionTests-\(UUID().uuidString)"
        let store = KeychainSessionStore(service: service, account: "session")
        defer { try? store.clear() }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "session",
            kSecValueData as String: Data("not a session".utf8)
        ]
        try #require(SecItemAdd(query as CFDictionary, nil) == errSecSuccess)

        #expect(throws: KeychainSessionStore.UndecodableItem.self) { try store.load() }
        #expect(throws: KeychainSessionStore.UndecodableItem.self, "still there: nothing removed it") { try store.load() }

        try store.clear()
        #expect(try store.load() == nil)
    }

    @Test("signing out removes an item that is not a session")
    func signOutRemovesUndecodableItem() async throws {
        let service = "AuthenticationSessionTests-\(UUID().uuidString)"
        let store = KeychainSessionStore(service: service, account: "session")
        defer { try? store.clear() }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "session",
            kSecValueData as String: Data("not a session".utf8)
        ]
        try #require(SecItemAdd(query as CFDictionary, nil) == errSecSuccess)
        let worker = FakeWorker()
        let authenticator = SessionAuthenticator(
            baseURL: worker.baseURL,
            installID: { "install-1" },
            store: store,
            urlSession: worker.urlSession
        )

        await #expect(throws: KeychainSessionStore.UndecodableItem.self) { try await authenticator.establishSession() }
        try await authenticator.signOut()

        #expect(try store.load() == nil)
        #expect(worker.paths.isEmpty, "nothing to revoke")
    }
}
