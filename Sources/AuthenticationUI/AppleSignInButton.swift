import SwiftUI
import AuthenticationServices
import Authentication

/// The official Sign in with Apple button, wired either to the store or to your own action.
///
/// It presents `ASAuthorizationAppleIDButton` rather than drawing anything. **Do not rebuild
/// Apple's treatment by hand** — the logo, wording, corner radius, minimum size and padding
/// are all specified, and a row assembled from the `apple.logo` symbol is not accepted as a
/// Sign in with Apple button, which is a review rejection. This type exists so no app has to
/// reproduce it.
///
/// What happens on tap comes in two forms:
///
/// - `init(style:type:onError:)` — signs in through the store in the environment, using
///   whichever Apple credential provider the composition root registered.
/// - `init(style:type:perform:)` — runs what you pass instead. **For apps that own their own
///   session**, such as linking an anonymous account, where the transition does not exist in
///   this package's store. They borrow the treatment without copying it.
public struct AppleSignInButton: View {
    @Environment(\.authenticationStore) private var store
    @State private var isLoading = false

    private let style: ASAuthorizationAppleIDButton.Style
    /// The wording on the button: sign in, continue, or sign up.
    ///
    /// **Match whatever stands next to it.** In an app that does not ask people to choose
    /// between registering and signing in, a button reading "Sign in" beside a Google button
    /// reading "Continue" is **read as doing something different before it is pressed** —
    /// which is exactly what users reported. Apple ships three variants for this reason.
    private let type: ASAuthorizationAppleIDButton.ButtonType
    /// What to run on tap. Only when this is `nil` does the button reach for the store.
    private let action: (@MainActor () async -> Void)?
    private let onError: (@MainActor (any Error) -> Void)?

    public init(
        style: ASAuthorizationAppleIDButton.Style = .black,
        type: ASAuthorizationAppleIDButton.ButtonType = .signIn,
        onError: (@MainActor (any Error) -> Void)? = nil
    ) {
        self.style = style
        self.type = type
        self.action = nil
        self.onError = onError
    }

    /// Creates a button that runs your action on tap.
    ///
    /// It never reads the store, so it stays enabled with nothing injected in the environment.
    public init(
        style: ASAuthorizationAppleIDButton.Style = .black,
        type: ASAuthorizationAppleIDButton.ButtonType = .signIn,
        perform action: @escaping @MainActor () async -> Void
    ) {
        self.style = style
        self.type = type
        self.action = action
        self.onError = nil
    }

    public var body: some View {
        AppleIDButtonRepresentable(style: style, type: type) {
            run()
        }
        .frame(height: 56)
        .disabled(isDisabled)
        .overlay {
            if isLoading {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.3))
                    .overlay { ProgressView().tint(.white) }
            }
        }
    }

    /// Disabled while a sign-in is running, and — in the store-backed form only — when no
    /// store was injected. The action form never reads the store, so its absence is not a
    /// reason to block the tap.
    private var isDisabled: Bool {
        isLoading || (action == nil && store == nil)
    }

    private func run() {
        isLoading = true
        Task {
            defer { isLoading = false }
            if let action {
                await action()
            } else {
                await signInWithStore()
            }
        }
    }

    private func signInWithStore() async {
        guard let store else { return }
        do {
            try await store.signIn(using: .apple)
        } catch let error as AuthError where error.code == .cancelled {
            // A dismissed sheet is a normal outcome, not something to report.
        } catch {
            onError?(error)
        }
    }
}

// MARK: - Official Apple button bridge

#if canImport(UIKit)
import UIKit

private struct AppleIDButtonRepresentable: UIViewRepresentable {
    let style: ASAuthorizationAppleIDButton.Style
    let type: ASAuthorizationAppleIDButton.ButtonType
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(authorizationButtonType: type, authorizationButtonStyle: style)
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.action = action
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func didTap() { action() }
    }
}
#elseif canImport(AppKit)
import AppKit

private struct AppleIDButtonRepresentable: NSViewRepresentable {
    let style: ASAuthorizationAppleIDButton.Style
    let type: ASAuthorizationAppleIDButton.ButtonType
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeNSView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(authorizationButtonType: type, authorizationButtonStyle: style)
        button.target = context.coordinator
        button.action = #selector(Coordinator.didTap)
        return button
    }

    func updateNSView(_ nsView: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.action = action
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func didTap() { action() }
    }
}
#endif

#Preview("Apple Sign-In Button") {
    AppleSignInButton()
        .padding()
        .authenticationStore(.previewUnauthenticated)
}
