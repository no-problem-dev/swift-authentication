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

    @Test("default provisioning contract is POST /auth/initialize")
    func defaultContract() {
        #expect(UserProvisioningContract.method == .post)
        #expect(UserProvisioningContract.resolvePath(with: UserProvisioningContract()) == "/auth/initialize")
    }

    /// 回帰: 応答本文の形をこのパッケージが決め打ちしてはいけない。
    ///
    /// かつて `Output` は `{ initialized, message }` を必須で要求しており、バックエンドが
    /// 別の形を返すとデコード失敗 → サインイン自体が通らなくなっていた（1.1.10 で 1.x 系を修正）。
    /// 既存のテストは `executeWithResponse` を差し替えるモックでデコード経路を迂回していたため
    /// この欠陥を検知できず、v2.0.0 の再設計で同じ形が復活していた。
    /// ここでは実デコーダに通し、どんな本文でも成功することを保つ。
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
        // デコードが成功すること自体が主張。形を要求する型に戻すと throw して落ちる。
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
