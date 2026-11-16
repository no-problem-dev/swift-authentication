import Foundation
import Authentication

/// A request to the session server that did not produce a session.
public enum SessionServerError: Error, Equatable, Sendable {
    /// The request never got an answer — no network, a timeout, a host that does not resolve.
    case unreachable(URLError)
    /// The server answered with a status outside 2xx. `reason` is the machine-readable
    /// `error.reason` from its body, such as `invalid_refresh_token` or
    /// `credential_already_in_use`, when there was one.
    case rejected(status: Int, reason: String?)
    /// The server answered 2xx with a body that is not a session.
    case malformedResponse

    /// The HTTP status of a rejection, `nil` otherwise.
    public var status: Int? {
        if case .rejected(let status, _) = self { return status }
        return nil
    }
}

/// A credential that cannot be sent to the session server.
public enum SessionCredentialError: Error, Equatable, Sendable {
    /// The credential is missing its ID token, or comes from a provider the server does not
    /// verify. Carries the credential's provider.
    case invalidCredential(AuthProviderID)
}

/// The session server's `/v1/auth/*` endpoints, and the app's account deletion endpoint.
///
/// Every request carries `requestTimeout`, whichever `URLSession` sends it, so the long
/// default holds for an injected session as well.
struct SessionServer: Sendable {
    let baseURL: URL
    let urlSession: URLSession
    let requestTimeout: TimeInterval

    func startAnonymous(installID: String) async throws -> AuthSession {
        try await session(from: post("v1/auth/anonymous", body: ["installId": installID]))
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        try await session(from: post("v1/auth/refresh", body: ["refreshToken": refreshToken]))
    }

    /// Signs in with a provider's token, or links it to the account `bearer` belongs to.
    func exchange(_ credential: AuthCredential, installID: String, bearer: String?) async throws -> AuthSession {
        guard let idToken = credential.idToken else {
            throw SessionCredentialError.invalidCredential(credential.provider)
        }
        let path: String
        let body: [String: String]
        switch credential.provider {
        case .apple:
            path = "v1/auth/apple"
            body = ["identityToken": idToken, "installId": installID]
        case .google:
            path = "v1/auth/google"
            body = ["idToken": idToken, "installId": installID]
        default:
            throw SessionCredentialError.invalidCredential(credential.provider)
        }
        return try await session(from: post(path, body: body, bearer: bearer))
    }

    func exchangeLegacy(idToken: String, installID: String) async throws -> AuthSession {
        try await session(from: post("v1/auth/firebase", body: ["idToken": idToken, "installId": installID]))
    }

    func signOut(bearer: String) async throws {
        _ = try await post("v1/auth/sign-out", body: [:], bearer: bearer)
    }

    func deleteAccount(path: String, bearer: String, appleAuthorizationCode: String?) async throws {
        var body: [String: String] = [:]
        body["appleAuthorizationCode"] = appleAuthorizationCode
        _ = try await send("DELETE", path, body: body, bearer: bearer)
    }

    // MARK: - Sending

    private func post(_ path: String, body: [String: String], bearer: String? = nil) async throws -> Data {
        try await send("POST", path, body: body, bearer: bearer)
    }

    private func send(_ method: String, _ path: String, body: [String: String], bearer: String?) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path), timeoutInterval: requestTimeout)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        if let bearer {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let error as URLError {
            throw SessionServerError.unreachable(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw SessionServerError.malformedResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let reason = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error.reason
            throw SessionServerError.rejected(status: http.statusCode, reason: reason)
        }
        return data
    }

    private func session(from data: Data) throws -> AuthSession {
        do {
            return try JSONDecoder().decode(AuthSession.self, from: data)
        } catch {
            throw SessionServerError.malformedResponse
        }
    }

    private struct ErrorBody: Decodable {
        struct Detail: Decodable {
            let reason: String?
        }
        let error: Detail
    }
}
