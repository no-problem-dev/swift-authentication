import Foundation

/// A user's name exactly as the sign-in provider gave it.
///
/// A small `Sendable` stand-in for `PersonNameComponents`. Either part can be missing —
/// providers return whatever the user chose to share — and Sign in with Apple hands the name
/// over only on the first authorization, so capture it then or lose it.
public struct PersonName: Hashable, Sendable {
    public let givenName: String?
    public let familyName: String?

    public init(givenName: String? = nil, familyName: String? = nil) {
        self.givenName = givenName
        self.familyName = familyName
    }

    /// Creates a name from name components, failing when there is nothing worth keeping.
    ///
    /// Returns `nil` for absent components and for components where both parts are missing,
    /// so an empty name never travels on a credential.
    ///
    /// - Parameter components: The components a provider returned.
    public init?(components: PersonNameComponents?) {
        guard let components else { return nil }
        guard components.givenName != nil || components.familyName != nil else { return nil }
        self.givenName = components.givenName
        self.familyName = components.familyName
    }
}
