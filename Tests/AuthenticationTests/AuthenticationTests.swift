import XCTest
import Foundation
@testable import Authentication
import APIClient
import APIContract

// MARK: - AuthenticationState Tests

final class AuthenticationStateTests: XCTestCase {

    func testIsAuthenticatedWhenAuthenticated() {
        let state = AuthenticationState.authenticated
        XCTAssertTrue(state.isAuthenticated)
    }

    func testIsAuthenticatedWhenUnauthenticated() {
        let state = AuthenticationState.unauthenticated
        XCTAssertFalse(state.isAuthenticated)
    }

    func testIsAuthenticatedWhenChecking() {
        let state = AuthenticationState.checking
        XCTAssertFalse(state.isAuthenticated)
    }

    func testIsAuthenticatedWhenFirebaseAuthenticatedOnly() {
        let state = AuthenticationState.firebaseAuthenticatedOnly
        XCTAssertFalse(state.isAuthenticated)
    }

    func testIsAuthenticatedWhenError() {
        let error = NSError(domain: "Test", code: 1)
        let state = AuthenticationState.error(error)
        XCTAssertFalse(state.isAuthenticated)
    }

    // MARK: - Equatable Tests

    func testEqualityChecking() {
        XCTAssertEqual(AuthenticationState.checking, AuthenticationState.checking)
    }

    func testEqualityUnauthenticated() {
        XCTAssertEqual(AuthenticationState.unauthenticated, AuthenticationState.unauthenticated)
    }

    func testEqualityFirebaseAuthenticatedOnly() {
        XCTAssertEqual(AuthenticationState.firebaseAuthenticatedOnly, AuthenticationState.firebaseAuthenticatedOnly)
    }

    func testEqualityAuthenticated() {
        XCTAssertEqual(AuthenticationState.authenticated, AuthenticationState.authenticated)
    }

    func testEqualityError() {
        let error1 = NSError(domain: "Test", code: 1)
        let error2 = NSError(domain: "Test", code: 2)
        // Error cases are equal regardless of the actual error
        XCTAssertEqual(AuthenticationState.error(error1), AuthenticationState.error(error2))
    }

    func testInequalityDifferentStates() {
        XCTAssertNotEqual(AuthenticationState.checking, AuthenticationState.authenticated)
        XCTAssertNotEqual(AuthenticationState.unauthenticated, AuthenticationState.firebaseAuthenticatedOnly)
        XCTAssertNotEqual(AuthenticationState.authenticated, AuthenticationState.error(NSError(domain: "", code: 0)))
    }
}

// MARK: - AuthError Tests

final class AuthErrorTests: XCTestCase {

    func testNotAuthenticated() {
        let error = AuthError.notAuthenticated
        XCTAssertNotNil(error)
    }

    func testGoogleSignInFailed() {
        let underlyingError = NSError(domain: "Google", code: 1)
        let error = AuthError.googleSignInFailed(underlyingError)

        if case .googleSignInFailed(let inner) = error {
            XCTAssertEqual((inner as NSError).domain, "Google")
        } else {
            XCTFail("Expected googleSignInFailed")
        }
    }

    func testAppleSignInFailed() {
        let underlyingError = NSError(domain: "Apple", code: 2)
        let error = AuthError.appleSignInFailed(underlyingError)

        if case .appleSignInFailed(let inner) = error {
            XCTAssertEqual((inner as NSError).domain, "Apple")
        } else {
            XCTFail("Expected appleSignInFailed")
        }
    }

    func testSignOutFailed() {
        let underlyingError = NSError(domain: "SignOut", code: 3)
        let error = AuthError.signOutFailed(underlyingError)

        if case .signOutFailed(let inner) = error {
            XCTAssertEqual((inner as NSError).domain, "SignOut")
        } else {
            XCTFail("Expected signOutFailed")
        }
    }

    func testDeleteAccountFailed() {
        let underlyingError = NSError(domain: "Delete", code: 4)
        let error = AuthError.deleteAccountFailed(underlyingError)

        if case .deleteAccountFailed(let inner) = error {
            XCTAssertEqual((inner as NSError).domain, "Delete")
        } else {
            XCTFail("Expected deleteAccountFailed")
        }
    }

    func testAPIAuthFailed() {
        let underlyingError = NSError(domain: "API", code: 5)
        let error = AuthError.apiAuthFailed(underlyingError)

        if case .apiAuthFailed(let inner) = error {
            XCTAssertEqual((inner as NSError).domain, "API")
        } else {
            XCTFail("Expected apiAuthFailed")
        }
    }

    func testUnknown() {
        let underlyingError = NSError(domain: "Unknown", code: 99)
        let error = AuthError.unknown(underlyingError)

        if case .unknown(let inner) = error {
            XCTAssertEqual((inner as NSError).domain, "Unknown")
        } else {
            XCTFail("Expected unknown")
        }
    }
}

// MARK: - SignInResult Tests

final class SignInResultTests: XCTestCase {

    func testSuccess() {
        let result = SignInResult.success

        if case .success = result {
            // OK
        } else {
            XCTFail("Expected success")
        }
    }

    func testFailure() {
        let error = AuthError.notAuthenticated
        let result = SignInResult.failure(error)

        if case .failure(let inner) = result {
            if case .notAuthenticated = inner {
                // OK
            } else {
                XCTFail("Expected notAuthenticated")
            }
        } else {
            XCTFail("Expected failure")
        }
    }
}

// MARK: - SignOutResult Tests

final class SignOutResultTests: XCTestCase {

    func testSuccess() {
        let result = SignOutResult.success

        if case .success = result {
            // OK
        } else {
            XCTFail("Expected success")
        }
    }

    func testFailure() {
        let error = AuthError.signOutFailed(NSError(domain: "", code: 0))
        let result = SignOutResult.failure(error)

        if case .failure = result {
            // OK
        } else {
            XCTFail("Expected failure")
        }
    }
}

// MARK: - DeleteAccountResult Tests

final class DeleteAccountResultTests: XCTestCase {

    func testSuccess() {
        let result = DeleteAccountResult.success

        if case .success = result {
            // OK
        } else {
            XCTFail("Expected success")
        }
    }

    func testFailure() {
        let error = AuthError.deleteAccountFailed(NSError(domain: "", code: 0))
        let result = DeleteAccountResult.failure(error)

        if case .failure = result {
            // OK
        } else {
            XCTFail("Expected failure")
        }
    }
}

// MARK: - InitializeUserResult Tests

final class InitializeUserResultTests: XCTestCase {

    func testInitializationSuccess() {
        let result = InitializeUserResult(initialized: true, message: "User initialized successfully")

        XCTAssertTrue(result.initialized)
        XCTAssertEqual(result.message, "User initialized successfully")
    }

    func testInitializationAlreadyExists() {
        let result = InitializeUserResult(initialized: false, message: "User already exists")

        XCTAssertFalse(result.initialized)
        XCTAssertEqual(result.message, "User already exists")
    }

    func testSendableConformance() {
        let result = InitializeUserResult(initialized: true, message: "Test")

        Task {
            _ = result
        }
    }
}

// MARK: - AuthInitializeContract Tests

final class AuthInitializeContractTests: XCTestCase {

    func testResolvePathWithCustomPath() {
        let contract = AuthInitializeContract(path: "/v1/auth/initialize")
        let resolvedPath = AuthInitializeContract.resolvePath(with: contract)

        XCTAssertEqual(resolvedPath, "/v1/auth/initialize")
    }

    func testResolvePathGenericCall() {
        // ジェネリック経由でもカスタム実装が呼ばれることを確認
        func resolveGeneric<E: APIContract>(_ contract: E) -> String
            where E.Input == E, E: APIInput
        {
            E.resolvePath(with: contract)
        }

        let contract = AuthInitializeContract(path: "/v2/users/init")
        let path = resolveGeneric(contract)
        XCTAssertEqual(path, "/v2/users/init")
    }

    func testMethod() {
        XCTAssertEqual(AuthInitializeContract.method, .post)
    }

    func testSubPath() {
        XCTAssertEqual(AuthInitializeContract.subPath, "")
    }

    func testPathParameters() {
        let contract = AuthInitializeContract(path: "/test")
        XCTAssertTrue(contract.pathParameters.isEmpty)
    }

    func testQueryParameters() {
        let contract = AuthInitializeContract(path: "/test")
        XCTAssertNil(contract.queryParameters)
    }

    func testEncodeBody() throws {
        let contract = AuthInitializeContract(path: "/test")
        let body = try contract.encodeBody(using: JSONEncoder())
        XCTAssertNil(body)
    }
}

// MARK: - AuthInitializeResponse Tests

final class AuthInitializeResponseTests: XCTestCase {

    func testDecodingSuccess() throws {
        let json = """
        {
            "initialized": true,
            "message": "User created"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try decoder.decode(AuthInitializeResponse.self, from: json)

        XCTAssertTrue(response.initialized)
        XCTAssertEqual(response.message, "User created")
    }

    func testDecodingExistingUser() throws {
        let json = """
        {
            "initialized": false,
            "message": "User already exists"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try decoder.decode(AuthInitializeResponse.self, from: json)

        XCTAssertFalse(response.initialized)
        XCTAssertEqual(response.message, "User already exists")
    }
}

// MARK: - Mock AuthRepository

final class MockAuthRepository: AuthRepository, @unchecked Sendable {
    nonisolated(unsafe) var isAuthenticatedResult: Bool = false
    nonisolated(unsafe) var signInWithGoogleResult: SignInResult = .success
    nonisolated(unsafe) var signInWithAppleResult: SignInResult = .success
    nonisolated(unsafe) var signOutResult: SignOutResult = .success
    nonisolated(unsafe) var deleteAccountResult: DeleteAccountResult = .success
    nonisolated(unsafe) var authStateStream: AsyncStream<Bool> = AsyncStream { $0.finish() }

    nonisolated(unsafe) var signInWithGoogleCallCount = 0
    nonisolated(unsafe) var signInWithAppleCallCount = 0
    nonisolated(unsafe) var signOutCallCount = 0
    nonisolated(unsafe) var deleteAccountCallCount = 0

    func isAuthenticated() async -> Bool {
        return isAuthenticatedResult
    }

    func signInWithGoogle() async -> SignInResult {
        signInWithGoogleCallCount += 1
        return signInWithGoogleResult
    }

    func signInWithApple(idToken: String, nonce: String) async -> SignInResult {
        signInWithAppleCallCount += 1
        return signInWithAppleResult
    }

    func signOut() async -> SignOutResult {
        signOutCallCount += 1
        return signOutResult
    }

    func deleteAccount() async -> DeleteAccountResult {
        deleteAccountCallCount += 1
        return deleteAccountResult
    }

    func observeAuthState() -> AsyncStream<Bool> {
        return authStateStream
    }
}

// MARK: - AuthServiceImpl Tests

final class AuthServiceImplTests: XCTestCase {

    func testIsAuthenticatedTrue() async {
        let mockRepo = MockAuthRepository()
        mockRepo.isAuthenticatedResult = true

        let service = AuthServiceImpl(authRepository: mockRepo)
        let result = await service.isAuthenticated()

        XCTAssertTrue(result)
    }

    func testIsAuthenticatedFalse() async {
        let mockRepo = MockAuthRepository()
        mockRepo.isAuthenticatedResult = false

        let service = AuthServiceImpl(authRepository: mockRepo)
        let result = await service.isAuthenticated()

        XCTAssertFalse(result)
    }

    func testSignInWithGoogleSuccess() async {
        let mockRepo = MockAuthRepository()
        mockRepo.signInWithGoogleResult = .success

        let service = AuthServiceImpl(authRepository: mockRepo)
        let result = await service.signInWithGoogle()

        XCTAssertEqual(mockRepo.signInWithGoogleCallCount, 1)
        if case .success = result {
            // OK
        } else {
            XCTFail("Expected success")
        }
    }

    func testSignInWithGoogleFailure() async {
        let mockRepo = MockAuthRepository()
        let error = NSError(domain: "Google", code: 1)
        mockRepo.signInWithGoogleResult = .failure(.googleSignInFailed(error))

        let service = AuthServiceImpl(authRepository: mockRepo)
        let result = await service.signInWithGoogle()

        if case .failure(let authError) = result {
            if case .googleSignInFailed = authError {
                // OK
            } else {
                XCTFail("Expected googleSignInFailed")
            }
        } else {
            XCTFail("Expected failure")
        }
    }

    func testSignInWithAppleSuccess() async {
        let mockRepo = MockAuthRepository()
        mockRepo.signInWithAppleResult = .success

        let service = AuthServiceImpl(authRepository: mockRepo)
        let result = await service.signInWithApple(idToken: "test-token", nonce: "test-nonce")

        XCTAssertEqual(mockRepo.signInWithAppleCallCount, 1)
        if case .success = result {
            // OK
        } else {
            XCTFail("Expected success")
        }
    }

    func testSignInWithAppleFailure() async {
        let mockRepo = MockAuthRepository()
        let error = NSError(domain: "Apple", code: 2)
        mockRepo.signInWithAppleResult = .failure(.appleSignInFailed(error))

        let service = AuthServiceImpl(authRepository: mockRepo)
        let result = await service.signInWithApple(idToken: "token", nonce: "nonce")

        if case .failure(let authError) = result {
            if case .appleSignInFailed = authError {
                // OK
            } else {
                XCTFail("Expected appleSignInFailed")
            }
        } else {
            XCTFail("Expected failure")
        }
    }

    func testSignOutSuccess() async {
        let mockRepo = MockAuthRepository()
        mockRepo.signOutResult = .success

        let service = AuthServiceImpl(authRepository: mockRepo)
        let result = await service.signOut()

        XCTAssertEqual(mockRepo.signOutCallCount, 1)
        if case .success = result {
            // OK
        } else {
            XCTFail("Expected success")
        }
    }

    func testSignOutFailure() async {
        let mockRepo = MockAuthRepository()
        let error = NSError(domain: "SignOut", code: 3)
        mockRepo.signOutResult = .failure(.signOutFailed(error))

        let service = AuthServiceImpl(authRepository: mockRepo)
        let result = await service.signOut()

        if case .failure(let authError) = result {
            if case .signOutFailed = authError {
                // OK
            } else {
                XCTFail("Expected signOutFailed")
            }
        } else {
            XCTFail("Expected failure")
        }
    }

    func testDeleteAccountSuccess() async {
        let mockRepo = MockAuthRepository()
        mockRepo.deleteAccountResult = .success

        let service = AuthServiceImpl(authRepository: mockRepo)
        let result = await service.deleteAccount()

        XCTAssertEqual(mockRepo.deleteAccountCallCount, 1)
        if case .success = result {
            // OK
        } else {
            XCTFail("Expected success")
        }
    }

    func testDeleteAccountFailure() async {
        let mockRepo = MockAuthRepository()
        let error = NSError(domain: "Delete", code: 4)
        mockRepo.deleteAccountResult = .failure(.deleteAccountFailed(error))

        let service = AuthServiceImpl(authRepository: mockRepo)
        let result = await service.deleteAccount()

        if case .failure(let authError) = result {
            if case .deleteAccountFailed = authError {
                // OK
            } else {
                XCTFail("Expected deleteAccountFailed")
            }
        } else {
            XCTFail("Expected failure")
        }
    }

    func testDeleteAccountNotAuthenticated() async {
        let mockRepo = MockAuthRepository()
        mockRepo.deleteAccountResult = .failure(.notAuthenticated)

        let service = AuthServiceImpl(authRepository: mockRepo)
        let result = await service.deleteAccount()

        if case .failure(let authError) = result {
            if case .notAuthenticated = authError {
                // OK
            } else {
                XCTFail("Expected notAuthenticated")
            }
        } else {
            XCTFail("Expected failure")
        }
    }

    func testObserveAuthState() async {
        let mockRepo = MockAuthRepository()
        mockRepo.authStateStream = AsyncStream { continuation in
            continuation.yield(true)
            continuation.yield(false)
            continuation.finish()
        }

        let service = AuthServiceImpl(authRepository: mockRepo)
        var states: [Bool] = []

        for await state in service.observeAuthState() {
            states.append(state)
        }

        XCTAssertEqual(states, [true, false])
    }
}

// MARK: - Mock APIExecutable

final class MockAPIExecutable: APIExecutable, @unchecked Sendable {
    nonisolated(unsafe) var executeResult: Any?
    nonisolated(unsafe) var executeError: Error?
    nonisolated(unsafe) var executedRequests: [Any] = []

    func execute<C: APIContract>(_ contract: C) async throws -> C.Output
        where C.Input == C, C: APIInput
    {
        executedRequests.append(contract)

        if let error = executeError {
            throw error
        }

        guard let result = executeResult as? C.Output else {
            throw NSError(domain: "MockError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Result type mismatch"
            ])
        }

        return result
    }

    func execute<E: APIContract>(_ contract: E) async throws
        where E.Input == E, E.Output == EmptyOutput, E: APIInput
    {
        executedRequests.append(contract)

        if let error = executeError {
            throw error
        }
    }
}

// MARK: - APIAuthRepositoryImpl Tests

final class APIAuthRepositoryImplTests: XCTestCase {

    func testInitializeUserSuccess() async throws {
        let mockClient = MockAPIExecutable()
        mockClient.executeResult = AuthInitializeResponse(initialized: true, message: "Created")

        let repository = APIAuthRepositoryImpl(apiClient: mockClient, authenticationPath: "/v1/auth")
        let result = try await repository.initializeUser()

        XCTAssertTrue(result.initialized)
        XCTAssertEqual(result.message, "Created")
        XCTAssertEqual(mockClient.executedRequests.count, 1)
    }

    func testInitializeUserAlreadyExists() async throws {
        let mockClient = MockAPIExecutable()
        mockClient.executeResult = AuthInitializeResponse(initialized: false, message: "Already exists")

        let repository = APIAuthRepositoryImpl(apiClient: mockClient, authenticationPath: "/v1/auth")
        let result = try await repository.initializeUser()

        XCTAssertFalse(result.initialized)
        XCTAssertEqual(result.message, "Already exists")
    }

    func testInitializeUserAPIError() async {
        let mockClient = MockAPIExecutable()
        mockClient.executeError = NSError(domain: "API", code: 500, userInfo: [
            NSLocalizedDescriptionKey: "Internal server error"
        ])

        let repository = APIAuthRepositoryImpl(apiClient: mockClient, authenticationPath: "/v1/auth")

        do {
            _ = try await repository.initializeUser()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual((error as NSError).domain, "API")
            XCTAssertEqual((error as NSError).code, 500)
        }
    }

    func testInitializeUserUsesCorrectPath() async throws {
        let mockClient = MockAPIExecutable()
        mockClient.executeResult = AuthInitializeResponse(initialized: true, message: "OK")

        let repository = APIAuthRepositoryImpl(apiClient: mockClient, authenticationPath: "/v2/custom/auth/path")
        _ = try await repository.initializeUser()

        guard let contract = mockClient.executedRequests.first as? AuthInitializeContract else {
            XCTFail("Expected AuthInitializeContract")
            return
        }

        XCTAssertEqual(contract.path, "/v2/custom/auth/path")
    }
}
