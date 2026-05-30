import Testing
import Foundation
import APIClient
import Authentication
@testable import AuthenticationAPI

enum MockError: Error { case boom, typeMismatch }

/// `executeWithResponse` のみ実装すれば `execute` 群は既定実装で動く。
final class MockAPIExecutable: APIExecutable, @unchecked Sendable {
    var executeCount = 0
    var stubbed: Any?
    var error: (any Error)?
    var lastPath: String?

    func executeWithResponse<E: APIContract>(
        _ contract: E
    ) async throws -> APIResponse<E.Output> where E.Input == E, E: APIInput {
        executeCount += 1
        lastPath = E.resolvePath(with: contract)
        if let error { throw error }
        guard let output = stubbed as? E.Output else { throw MockError.typeMismatch }
        return APIResponse(output: output, statusCode: 200, headers: [:])
    }
}

@Suite("APIUserProvisioning")
struct APIUserProvisioningTests {
    @Test("perform executes the provisioning contract once at the configured path")
    func performExecutes() async throws {
        let mock = MockAPIExecutable()
        mock.stubbed = UserProvisioningResponse(initialized: true, message: "ok")
        let provisioning = APIUserProvisioning(apiClient: mock, path: "/v1/auth/initialize")

        try await provisioning.perform(for: AuthUser(id: "u"))

        #expect(mock.executeCount == 1)
        #expect(mock.lastPath == "/v1/auth/initialize")
    }

    @Test("perform propagates API errors")
    func performPropagatesError() async {
        let mock = MockAPIExecutable()
        mock.error = MockError.boom
        let provisioning = APIUserProvisioning(apiClient: mock)

        await #expect(throws: MockError.self) {
            try await provisioning.perform(for: AuthUser(id: "u"))
        }
    }

    @Test("default provisioning contract is POST /auth/initialize")
    func defaultContract() {
        #expect(UserProvisioningContract.method == .post)
        #expect(UserProvisioningContract.resolvePath(with: UserProvisioningContract()) == "/auth/initialize")
    }
}
