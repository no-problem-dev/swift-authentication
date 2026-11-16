import Testing
import Foundation
import Authentication
@testable import AuthenticationSession

/// What the session server is sent, what is never forwarded, and what happens when two
/// processes — the app and an extension in the same keychain access group — share one store.
@Suite("Session hardening")
struct SessionHardeningTests {

    private func make(_ worker: FakeWorker, store: InMemorySessionStore = InMemorySessionStore()) -> SessionAuthenticator {
        SessionAuthenticator(
            baseURL: worker.baseURL,
            installID: { "install-1" },
            store: store,
            urlSession: worker.urlSession
        )
    }

    // MARK: - Nonce

    @Test("Apple and Google sign-ins send the raw nonce, so the server can match the token's hash")
    func sendsRawNonce() async throws {
        let worker = FakeWorker()
        let authenticator = make(worker)

        _ = try await authenticator.signIn(with: AuthCredential(provider: .apple, idToken: "apple-sub-1", rawNonce: "raw-apple"))
        _ = try await authenticator.signIn(with: AuthCredential(provider: .google, idToken: "google-sub-1", rawNonce: "raw-google"))

        let apple = try #require(worker.recorded.first { $0.path == "/v1/auth/apple" })
        let google = try #require(worker.recorded.first { $0.path == "/v1/auth/google" })
        #expect(apple.body["nonce"] == "raw-apple")
        #expect(google.body["nonce"] == "raw-google")
    }

    @Test("a credential without a nonce sends no nonce key")
    func omitsMissingNonce() async throws {
        let worker = FakeWorker()
        let authenticator = make(worker)

        _ = try await authenticator.signIn(with: AuthCredential(provider: .google, idToken: "google-sub-1"))

        let google = try #require(worker.recorded.first { $0.path == "/v1/auth/google" })
        #expect(google.body["nonce"] == nil)
    }

    // MARK: - Redirects

    @Test("a redirect is refused, so the refresh token and the bearer never reach another host")
    func refusesRedirects() async throws {
        let worker = FakeWorker()
        let elsewhere = FakeWorker()
        let store = InMemorySessionStore()
        let authenticator = make(worker, store: store)
        try await authenticator.establishSession()
        worker.update { $0.redirects["/v1/auth/refresh"] = elsewhere.baseURL.appending(path: "v1/auth/refresh") }

        await #expect(throws: SessionServerError.self) {
            _ = try await authenticator.tokenProvider.token(forceRefresh: true)
        }
        #expect(elsewhere.recorded.isEmpty, "nothing was sent to the host the redirect named")
    }

    // MARK: - A store shared with another process

    /// Two authenticators over one store stand in for the app and an extension: each keeps its
    /// own copy in memory, as two processes would.
    @Test("a refresh rejected for a session another process already replaced keeps the new session")
    func rejectedRefreshKeepsNewerSession() async throws {
        let worker = FakeWorker()
        let store = InMemorySessionStore()
        let app = make(worker, store: store)
        let widget = make(worker, store: store)
        let first = try await app.establishSession()
        _ = try await widget.tokenProvider.token(forceRefresh: false)
        let firstRefresh = try #require(try store.load()).refreshToken

        try await app.signOut()
        let second = try await app.establishSession()
        worker.update { $0.revokedRefreshTokens = [firstRefresh] }

        let token = try await widget.tokenProvider.token(forceRefresh: true)

        #expect(second.id != first.id)
        #expect(try store.load()?.user.id == second.id, "the app's new session is still stored")
        #expect(token != nil, "the extension carries on with the session the store holds now")
        #expect(await widget.currentUser()?.id == second.id)
    }

    @Test("a refresh that succeeds for a session another process replaced does not write it back")
    func staleRefreshDoesNotOverwrite() async throws {
        let worker = FakeWorker()
        let store = InMemorySessionStore()
        let app = make(worker, store: store)
        let widget = make(worker, store: store)
        let first = try await app.establishSession()
        _ = try await widget.tokenProvider.token(forceRefresh: false)

        // Signed out while the revocation could not reach the server: the old refresh token works.
        worker.update { $0.unreachablePaths = ["/v1/auth/sign-out"] }
        try await app.signOut()
        let second = try await app.establishSession()

        _ = try await widget.tokenProvider.token(forceRefresh: true)

        #expect(second.id != first.id)
        #expect(try store.load()?.user.id == second.id, "the previous user's session is not written back")
        #expect(await widget.currentUser()?.id == second.id)
    }

    @Test("a refresh after another process signed out does not bring the session back")
    func refreshAfterOtherSignOut() async throws {
        let worker = FakeWorker()
        let store = InMemorySessionStore()
        let app = make(worker, store: store)
        let widget = make(worker, store: store)
        try await app.establishSession()
        _ = try await widget.tokenProvider.token(forceRefresh: false)
        worker.update { $0.unreachablePaths = ["/v1/auth/sign-out"] }
        try await app.signOut()

        await #expect(throws: AuthError.self) {
            _ = try await widget.tokenProvider.token(forceRefresh: true)
        }
        #expect(try store.load() == nil)
        #expect(await widget.currentUser() == nil)
    }
}

@Suite("AuthSession redaction")
struct AuthSessionRedactionTests {
    @Test("a session prints its user and none of its tokens")
    func redacted() {
        let session = AuthSession(
            user: .init(id: "u1", linkedProviders: [.apple], createdAt: Date(timeIntervalSince1970: 0)),
            accessToken: "SECRET-ACCESS",
            accessTokenExpiresAt: Date(timeIntervalSince1970: 60),
            refreshToken: "SECRET-REFRESH"
        )
        var dumped = ""
        dump(session, to: &dumped)
        for text in [String(describing: session), String(reflecting: session), "\(Optional(session) as Any)", dumped] {
            #expect(!text.contains("SECRET"), "\(text)")
            #expect(text.contains("u1"))
        }
    }
}
