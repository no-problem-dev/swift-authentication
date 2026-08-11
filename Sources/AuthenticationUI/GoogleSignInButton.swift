import SwiftUI
import Authentication

/// A Google Sign-In button that follows Google's branding rules.
///
/// The mark is the real logo, shipped as a resource of this target — a lookalike such as the
/// `g.circle` symbol is not an acceptable substitute. On tap it offers the same two forms as
/// ``AppleSignInButton``:
///
/// - `init(title:onError:)` — signs in through the store in the environment.
/// - `init(title:perform:)` — runs what you pass instead. **For apps that own their own
///   session**, which borrow the treatment without copying it.
public struct GoogleSignInButton: View {
    @Environment(\.authenticationStore) private var store
    @State private var isLoading = false

    private let title: String
    /// What to run on tap. Only when this is `nil` does the button reach for the store.
    private let action: (@MainActor () async -> Void)?
    private let onError: (@MainActor (any Error) -> Void)?

    public init(
        title: String = "Sign in with Google",
        onError: (@MainActor (any Error) -> Void)? = nil
    ) {
        self.title = title
        self.action = nil
        self.onError = onError
    }

    /// Creates a button that runs your action on tap, leaving the store untouched.
    public init(
        title: String = "Sign in with Google",
        perform action: @escaping @MainActor () async -> Void
    ) {
        self.title = title
        self.action = action
        self.onError = nil
    }

    public var body: some View {
        Button(action: run) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(.primary)
                        .frame(width: 20, height: 20)
                } else {
                    Image("google-logo", bundle: .module)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(GoogleSignInButtonStyle())
        .disabled(isDisabled)
    }

    /// Disabled while a sign-in is running, and — in the store-backed form only — when no
    /// store was injected.
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
            try await store.signIn(using: .google)
        } catch let error as AuthError where error.code == .cancelled {
            // A dismissed consent screen is a normal outcome, not something to report.
        } catch {
            onError?(error)
        }
    }
}

/// The outlined style used by the Google button, exposed for buttons you build yourself.
///
/// It carries the corner radius, border and press feedback that keep a custom Google button
/// visually consistent with ``AppleSignInButton`` when the two are stacked.
public struct GoogleSignInButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.primary.opacity(0.3), lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.background))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview("Google Sign-In Button") {
    GoogleSignInButton()
        .padding()
        .authenticationStore(.previewUnauthenticated)
}
