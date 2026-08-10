import SwiftUI
import Authentication

public extension EnvironmentValues {
    /// The session store for this view tree, or `nil` when nothing injected one.
    ///
    /// Views read it to observe the session; the composition root is what puts it there.
    @Entry var authenticationStore: AuthenticationStore? = nil
}

public extension View {
    /// Puts an authentication store into the environment for this view and everything below it.
    ///
    /// - Parameter store: The store assembled at the composition root.
    func authenticationStore(_ store: AuthenticationStore) -> some View {
        environment(\.authenticationStore, store)
    }
}
