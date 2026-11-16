import Foundation
@testable import AuthenticationSession

/// The session server's `/v1/auth/*` endpoints, played in memory.
///
/// Each test makes its own worker, which gets a host of its own; ``FakeWorkerProtocol`` routes
/// a request to the worker that owns its host, so suites running in parallel never meet.
final class FakeWorker: @unchecked Sendable {
    struct Request: Sendable {
        let method: String
        let path: String
        let authorization: String?
        let body: [String: String]
    }

    let baseURL: URL
    private let lock = NSLock()
    private var requests: [Request] = []
    private var issued = 0

    // What the server knows. Tokens are "access-<n>"; each refresh token belongs to one user.
    private var userIDByAccessToken: [String: String] = [:]
    private var userIDByRefreshToken: [String: String] = [:]
    private var linkedProvidersByUserID: [String: [String]] = [:]
    private var userIDBySubject: [String: String] = [:]

    // Knobs a test turns.
    var accessTokenLifetime: TimeInterval = 24 * 60 * 60
    var refreshDelay: TimeInterval = 0
    var revokedRefreshTokens: Set<String> = []
    var failLegacyExchange = false
    var deletedUserIDs: Set<String> = []
    var unreachablePaths: Set<String> = []

    init() {
        baseURL = URL(string: "https://\(UUID().uuidString.lowercased()).worker.test")!
        FakeWorkerProtocol.register(self, host: baseURL.host()!)
    }

    var recorded: [Request] { lock.withLock { requests } }
    var paths: [String] { recorded.map { "\($0.method) \($0.path)" } }

    /// A URL session whose requests reach this worker and nothing else.
    var urlSession: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeWorkerProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// Puts an account on the server, owned by a provider subject such as `apple:sub-1`.
    func seedAccount(userID: String, subject: String, provider: String) {
        lock.withLock {
            userIDBySubject[subject] = userID
            linkedProvidersByUserID[userID] = [provider]
        }
    }

    func update(_ change: (FakeWorker) -> Void) {
        lock.withLock { change(self) }
    }

    /// Answers one request: a status, a body, and how long to wait before answering.
    func respond(to request: URLRequest) -> (status: Int, body: Data, delay: TimeInterval)? {
        lock.withLock {
            let path = request.url?.path() ?? ""
            let body = Self.body(of: request)
            let recorded = Request(
                method: request.httpMethod ?? "GET",
                path: path,
                authorization: request.value(forHTTPHeaderField: "Authorization"),
                body: body
            )
            requests.append(recorded)
            if unreachablePaths.contains(path) { return nil }
            let bearerUserID = recorded.authorization
                .flatMap { $0.hasPrefix("Bearer ") ? String($0.dropFirst(7)) : nil }
                .flatMap { userIDByAccessToken[$0] }

            switch path {
            case "/v1/auth/anonymous":
                return issue(for: "user-\(UUID().uuidString.prefix(8))", providers: ["anonymous"], status: 201)

            case "/v1/auth/refresh":
                let token = body["refreshToken"] ?? ""
                guard !revokedRefreshTokens.contains(token), let userID = userIDByRefreshToken[token] else {
                    return Self.error(401, "invalid_refresh_token")
                }
                return issue(for: userID, refreshToken: token, delay: refreshDelay)

            case "/v1/auth/apple", "/v1/auth/google":
                let provider = path == "/v1/auth/apple" ? "apple" : "google"
                guard let token = body[provider == "apple" ? "identityToken" : "idToken"] else {
                    return Self.error(400, "bad_request")
                }
                let subject = "\(provider):\(token)"
                let signInExisting = body["mode"] == "sign_in_existing"
                if let owner = userIDBySubject[subject] {
                    if deletedUserIDs.contains(owner) { return Self.error(410, "account_deleted") }
                    if !signInExisting, let bearerUserID, bearerUserID != owner {
                        return Self.error(409, "credential_already_in_use")
                    }
                    return issue(for: owner)
                }
                if signInExisting { return Self.error(404, "account_not_found") }
                let userID = bearerUserID ?? "user-\(UUID().uuidString.prefix(8))"
                userIDBySubject[subject] = userID
                let providers = (linkedProvidersByUserID[userID] ?? []).filter { $0 != "anonymous" } + [provider]
                linkedProvidersByUserID[userID] = providers
                return issue(for: userID)

            case "/v1/auth/firebase":
                guard !failLegacyExchange, let idToken = body["idToken"] else {
                    return Self.error(401, "invalid_firebase_token")
                }
                let userID = idToken.replacingOccurrences(of: "firebase-token-", with: "")
                if deletedUserIDs.contains(userID) { return Self.error(410, "account_deleted") }
                return issue(for: userID, providers: ["anonymous"])

            case "/v1/auth/sign-out":
                guard bearerUserID != nil else { return Self.error(401, "invalid_token") }
                return (204, Data(), 0)

            case let path where path.hasPrefix("/v1/auth/identities/"):
                guard let bearerUserID else { return Self.error(401, "invalid_token") }
                let provider = String(path.dropFirst("/v1/auth/identities/".count))
                var providers = linkedProvidersByUserID[bearerUserID] ?? []
                guard providers.contains(provider) else { return Self.error(404, "identity_not_linked") }
                providers.removeAll { $0 == provider }
                linkedProvidersByUserID[bearerUserID] = providers.isEmpty ? ["anonymous"] : providers
                userIDBySubject = userIDBySubject.filter { !($0.key.hasPrefix("\(provider):") && $0.value == bearerUserID) }
                return (200, try! JSONSerialization.data(withJSONObject: userJSON(bearerUserID)), 0)

            case "/v1/account":
                guard bearerUserID != nil else { return Self.error(401, "invalid_token") }
                return (204, Data(), 0)

            default:
                return Self.error(404, "not_found")
            }
        }
    }

    // Called with the lock held.
    private func issue(
        for userID: String,
        providers: [String]? = nil,
        refreshToken: String? = nil,
        status: Int = 200,
        delay: TimeInterval = 0
    ) -> (status: Int, body: Data, delay: TimeInterval) {
        issued += 1
        if let providers, linkedProvidersByUserID[userID] == nil {
            linkedProvidersByUserID[userID] = providers
        }
        let accessToken = "access-\(issued)"
        let refresh = refreshToken ?? "device-\(issued).secret"
        userIDByAccessToken[accessToken] = userID
        userIDByRefreshToken[refresh] = userID
        let json: [String: Any] = [
            "user": userJSON(userID),
            "accessToken": accessToken,
            "accessTokenExpiresAt": Int64((Date().timeIntervalSince1970 + accessTokenLifetime) * 1000),
            "refreshToken": refresh
        ]
        return (status, try! JSONSerialization.data(withJSONObject: json), delay)
    }

    // Called with the lock held.
    private func userJSON(_ userID: String) -> [String: Any] {
        [
            "id": userID,
            "linkedProviders": linkedProvidersByUserID[userID] ?? ["anonymous"],
            "createdAt": 1_763_251_200_000
        ]
    }

    private static func error(_ status: Int, _ reason: String) -> (status: Int, body: Data, delay: TimeInterval) {
        let json = ["error": ["reason": reason, "message": reason]]
        return (status, try! JSONSerialization.data(withJSONObject: json), 0)
    }

    /// URLSession hands a protocol the body as a stream, not as `httpBody`.
    private static func body(of request: URLRequest) -> [String: String] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(buffer, count: count)
            }
        }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }
}

/// Routes requests to the ``FakeWorker`` registered for their host.
final class FakeWorkerProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var workers: [String: FakeWorker] = [:]

    static func register(_ worker: FakeWorker, host: String) {
        lock.withLock { workers[host] = worker }
    }

    private static func worker(for host: String) -> FakeWorker? {
        lock.withLock { workers[host] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let worker = url.host().flatMap(Self.worker(for:)),
              let answer = worker.respond(to: request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + answer.delay) { [self] in
            let response = HTTPURLResponse(url: url, statusCode: answer.status, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: answer.body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
