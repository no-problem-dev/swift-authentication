import Testing
import Foundation
import Authentication
@testable import AuthenticationAPI

/// テスト用の `AuthTokenProviding` モック。
private final class MockTokenProviding: AuthTokenProviding, @unchecked Sendable {
    var result: Result<String?, any Error>

    init(result: Result<String?, any Error>) {
        self.result = result
    }

    func token() async throws -> String? {
        try result.get()
    }
}

@Suite("APITokenProviderAdapter")
struct APITokenProviderAdapterTests {
    @Test("getToken passes the underlying token through")
    func passesTokenThrough() async throws {
        let adapter = APITokenProviderAdapter(MockTokenProviding(result: .success("id-token")))
        let token = try await adapter.getToken()
        #expect(token == "id-token")
    }

    @Test("getToken returns nil when unauthenticated")
    func passesNilThrough() async throws {
        let adapter = APITokenProviderAdapter(MockTokenProviding(result: .success(nil)))
        let token = try await adapter.getToken()
        #expect(token == nil)
    }

    @Test("token acquisition failure propagates instead of degrading to nil")
    func propagatesFailure() async {
        let adapter = APITokenProviderAdapter(MockTokenProviding(result: .failure(MockError.boom)))
        await #expect(throws: MockError.self) {
            _ = try await adapter.getToken()
        }
    }
}
