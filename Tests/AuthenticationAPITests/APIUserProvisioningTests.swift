import Testing
import Foundation
import APIClient
import APIContract
import Authentication
@testable import AuthenticationAPI

enum MockError: Error { case boom, typeMismatch }

/// Overriding `executeWithResponse` alone is enough: the `execute` family runs on the
/// protocol's default implementations.
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
        mock.stubbed = EmptyOutput()
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

    /// A 401 and a 403 both stop provisioning, and want opposite responses. Passing the
    /// `APIError` through would leave that to the caller's guess.
    @Test(
        "a rejected session and a refused account are told apart",
        arguments: [
            (APIError.unauthorized(data: Data(#"{"error":"expired"}"#.utf8)), AuthError.Code.sessionExpired),
            (APIError.forbidden(data: Data(#"{"error":"plan"}"#.utf8)), AuthError.Code.notPermitted)
        ]
    )
    func performNamesAuthFailures(apiError: APIError, expected: AuthError.Code) async {
        let mock = MockAPIExecutable()
        mock.error = apiError
        let provisioning = APIUserProvisioning(apiClient: mock)

        do {
            try await provisioning.perform(for: AuthUser(id: "u"))
            Issue.record("expected throw")
        } catch let error as AuthError {
            #expect(error.code == expected)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("any other API error is passed through unchanged")
    func performPassesOtherAPIErrorsThrough() async {
        let mock = MockAPIExecutable()
        mock.error = APIError.httpError(statusCode: 500, data: Data())
        let provisioning = APIUserProvisioning(apiClient: mock)

        await #expect(throws: APIError.self) {
            try await provisioning.perform(for: AuthUser(id: "u"))
        }
    }

    @Test("default provisioning contract is POST /auth/initialize")
    func defaultContract() {
        #expect(UserProvisioningContract.method == .post)
        #expect(UserProvisioningContract.resolvePath(with: UserProvisioningContract()) == "/auth/initialize")
    }

    /// Regression: this package must not dictate the shape of the response body.
    ///
    /// `Output` once required `{ initialized, message }`, so a backend that answered with
    /// anything else failed to decode and sign-in stopped working outright (fixed for the 1.x
    /// line in 1.1.10). The tests of the day mocked `executeWithResponse` and so skipped the
    /// decoding path entirely, which is why the same shape came back during the 2.0.0
    /// redesign. This one runs a real decoder and holds any body to be acceptable.
    @Test(
        "provisioning output ignores the response body shape",
        arguments: [
            #"{"initialized":true,"message":"ok"}"#,
            #"{"status":"created"}"#,
            #"{"nested":{"x":true},"count":3}"#,
            "{}",
            "null"
        ]
    )
    func outputIgnoresBodyShape(json: String) throws {
        // Decoding succeeding is the assertion. A type that demands a shape throws here.
        _ = try JSONDecoder().decode(
            UserProvisioningContract.Output.self,
            from: Data(json.utf8)
        )
    }

    @Test("provisioning contract declares an empty output")
    func outputIsEmpty() {
        #expect(UserProvisioningContract.Output.self == EmptyOutput.self)
    }
}
