import Foundation
import APIClient
import APIContract

/// The request this package sends to provision a user: a `POST` to a caller-chosen path.
///
/// A self-encoding contract (`Input == Self`) whose path belongs to the instance rather than
/// the type, so one contract serves any endpoint.
///
/// The response body is deliberately left unread. All this package needs is success or
/// failure, and body shapes differ per app: demanding a fixed payload would turn any backend
/// change into a decoding error, which reaches the user as sign-in being broken.
public struct UserProvisioningContract: APIContract, APIInput {
    public typealias Input = Self
    public typealias Output = EmptyOutput

    public static var method: APIMethod { .post }
    public static var subPath: String { "" }

    public let path: String

    public init(path: String = "/auth/initialize") {
        self.path = path
    }

    /// Returns the path carried by the instance, ignoring the group and sub-path the protocol
    /// would otherwise assemble.
    public static func resolvePath(with input: Self) -> String {
        input.path
    }

    /// Never used: this contract is only ever sent, so decoding an incoming request yields an
    /// empty value rather than a meaningful one.
    public static func decode(
        pathParameters: [String: String],
        queryParameters: [String: String],
        body: Data?,
        decoder: any APIBodyDecoder
    ) throws -> Self {
        Self(path: "")
    }
}
