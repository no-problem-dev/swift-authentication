import Foundation
import Authentication

/// A session the session server issued: who the person is, and the tokens that prove it.
///
/// The same shape the server returns from every `/v1/auth/*` endpoint, and the shape a
/// ``SessionStore`` keeps on the device. Times are epoch milliseconds on the wire.
///
/// - Warning: The tokens are bearer secrets. Do not log an instance of this type.
public struct AuthSession: Sendable, Equatable, Codable {
    /// The person the session belongs to.
    public struct User: Sendable, Equatable, Codable {
        /// The user id the server issued. Stable across refreshes and devices.
        public let id: String
        /// The providers the server lists for the account, as it lists them: `apple` and
        /// `google` once linked, and `anonymous` alone while neither is.
        public let linkedProviders: [AuthProviderID]
        /// When the account was created.
        public let createdAt: Date

        public init(id: String, linkedProviders: [AuthProviderID], createdAt: Date) {
            self.id = id
            self.linkedProviders = linkedProviders
            self.createdAt = createdAt
        }

        /// The user in the core's vocabulary: ``AuthUser/providerIDs`` holds the providers that
        /// prove who the person is, without `anonymous`, and is empty while anonymous. The
        /// server reports no email or display name.
        public var authUser: AuthUser {
            let providerIDs = linkedProviders.filter { $0 != .anonymous }
            return AuthUser(id: id, isAnonymous: providerIDs.isEmpty, providerIDs: providerIDs)
        }

        private enum CodingKeys: String, CodingKey {
            case id, linkedProviders, createdAt
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            linkedProviders = try container.decode([String].self, forKey: .linkedProviders)
                .map(AuthProviderID.init(rawValue:))
            createdAt = try container.decode(EpochMilliseconds.self, forKey: .createdAt).date
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(linkedProviders.map(\.rawValue), forKey: .linkedProviders)
            try container.encode(EpochMilliseconds(createdAt), forKey: .createdAt)
        }
    }

    public let user: User
    /// The bearer token the app's API accepts.
    public let accessToken: String
    /// When ``accessToken`` stops being accepted.
    public let accessTokenExpiresAt: Date
    /// The device's key for a new access token. The server keeps returning the same value.
    public let refreshToken: String

    public init(user: User, accessToken: String, accessTokenExpiresAt: Date, refreshToken: String) {
        self.user = user
        self.accessToken = accessToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
        self.refreshToken = refreshToken
    }

    private enum CodingKeys: String, CodingKey {
        case user, accessToken, accessTokenExpiresAt, refreshToken
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decode(User.self, forKey: .user)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        accessTokenExpiresAt = try container.decode(EpochMilliseconds.self, forKey: .accessTokenExpiresAt).date
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(user, forKey: .user)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(EpochMilliseconds(accessTokenExpiresAt), forKey: .accessTokenExpiresAt)
        try container.encode(refreshToken, forKey: .refreshToken)
    }
}

// Logs, crash reports and `dump` print a value through these. The tokens stay out of all of them.
extension AuthSession: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String {
        "AuthSession(user: \(user.id), linkedProviders: \(user.linkedProviders.map(\.rawValue)), "
            + "accessToken: <redacted>, accessTokenExpiresAt: \(accessTokenExpiresAt), refreshToken: <redacted>)"
    }

    public var debugDescription: String { description }

    public var customMirror: Mirror {
        Mirror(
            self,
            children: ["user": user, "accessTokenExpiresAt": accessTokenExpiresAt, "tokens": "<redacted>"],
            displayStyle: .struct
        )
    }
}

/// A point in time as the server writes it: milliseconds since 1970, as a JSON number.
private struct EpochMilliseconds: Codable {
    let date: Date

    init(_ date: Date) {
        self.date = date
    }

    init(from decoder: any Decoder) throws {
        let milliseconds = try decoder.singleValueContainer().decode(Double.self)
        date = Date(timeIntervalSince1970: milliseconds / 1000)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Int64((date.timeIntervalSince1970 * 1000).rounded()))
    }
}
