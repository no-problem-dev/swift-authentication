import Testing
import Foundation
import APIClient
import APIContract
import Authentication
@testable import AuthenticationAPI

@Suite("APIAccountDeletion")
struct APIAccountDeletionTests {
    @Test("deleteAccount sends one DELETE to the configured path")
    func sendsDelete() async throws {
        let mock = MockAPIExecutable()
        mock.stubbed = EmptyOutput()
        let deletion = APIAccountDeletion(apiClient: mock, path: "/v1/me")

        try await deletion.deleteAccount(of: AuthUser(id: "u"))

        #expect(mock.executeCount == 1)
        #expect(mock.lastPath == "/v1/me")
        #expect(AccountDeletionContract.method == .delete)
    }

    @Test(
        "a rejected session and a refused account are told apart",
        arguments: [
            (APIError.unauthorized(data: Data()), AuthError.Code.sessionExpired),
            (APIError.forbidden(data: Data()), AuthError.Code.notPermitted)
        ]
    )
    func namesAuthFailures(apiError: APIError, expected: AuthError.Code) async {
        let mock = MockAPIExecutable()
        mock.error = apiError
        let deletion = APIAccountDeletion(apiClient: mock, path: "/v1/me")

        await #expect {
            try await deletion.deleteAccount(of: AuthUser(id: "u"))
        } throws: { ($0 as? AuthError)?.code == expected }
    }

    @Test("any other failure propagates unchanged")
    func propagatesOtherErrors() async {
        let mock = MockAPIExecutable()
        mock.error = MockError.boom
        let deletion = APIAccountDeletion(apiClient: mock, path: "/v1/me")

        await #expect(throws: MockError.self) {
            try await deletion.deleteAccount(of: AuthUser(id: "u"))
        }
    }
}
