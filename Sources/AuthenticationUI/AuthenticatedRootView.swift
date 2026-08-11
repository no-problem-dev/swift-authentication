import SwiftUI
import Authentication

/// Shows a different subtree for each stage of the session.
///
/// It reads the store from the environment and switches on its state, holding none of its own.
/// Checking and pending provisioning share the loading branch, which is why there are four
/// builders rather than five.
///
/// With no store in the environment it renders a configuration error instead of an empty
/// screen, so a missed injection is visible during development rather than silent.
public struct AuthenticatedRootView<
    LoadingView: View,
    UnauthenticatedView: View,
    ErrorView: View,
    AuthenticatedView: View
>: View {
    @Environment(\.authenticationStore) private var store

    private let loadingView: () -> LoadingView
    private let unauthenticatedView: () -> UnauthenticatedView
    private let errorView: (any Error) -> ErrorView
    private let authenticatedView: (AuthUser) -> AuthenticatedView

    /// Creates the root view from one builder per stage.
    ///
    /// - Parameters:
    ///   - loading: Shown while the stored session is being checked and while post-sign-in
    ///     work runs.
    ///   - unauthenticated: Shown when there is no session — the sign-in screen.
    ///   - error: Shown when the flow failed, receiving the underlying error.
    ///   - authenticated: Shown once the user is signed in and provisioned.
    public init(
        @ViewBuilder loading: @escaping () -> LoadingView,
        @ViewBuilder unauthenticated: @escaping () -> UnauthenticatedView,
        @ViewBuilder error: @escaping (any Error) -> ErrorView,
        @ViewBuilder authenticated: @escaping (AuthUser) -> AuthenticatedView
    ) {
        self.loadingView = loading
        self.unauthenticatedView = unauthenticated
        self.errorView = error
        self.authenticatedView = authenticated
    }

    public var body: some View {
        if let store {
            content(for: store.state)
        } else {
            ConfigurationErrorView()
        }
    }

    @ViewBuilder
    private func content(for state: AuthenticationState) -> some View {
        switch state {
        case .checking, .authenticatedPendingProvisioning:
            loadingView()
        case .unauthenticated:
            unauthenticatedView()
        case .authenticated(let user):
            authenticatedView(user)
        case .error(let error):
            errorView(error)
        }
    }
}

private struct ConfigurationErrorView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            Text("Authentication configuration error")
                .font(.title)
            Text("No AuthenticationStore is set in the environment")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview("Unauthenticated") {
    AuthenticatedRootView(
        loading: { ProgressView() },
        unauthenticated: {
            VStack(spacing: 16) {
                Text("Sign in").font(.title)
                GoogleSignInButton()
                AppleSignInButton()
            }
            .padding(.horizontal, 32)
        },
        error: { Text("Error: \($0.localizedDescription)") },
        authenticated: { user in Text("Welcome, \(user.id)") }
    )
    .authenticationStore(.previewUnauthenticated)
}
