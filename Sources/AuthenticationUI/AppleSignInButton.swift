import SwiftUI
import AuthenticationServices
import Authentication

/// Sign in with Apple ボタン。
///
/// 公式の `ASAuthorizationAppleIDButton` を表示し、タップで
/// `authenticationStore.signIn(using: .apple)` を実行する。資格情報の取得フローは
/// 合成ルートで注入された `AppleCredentialProvider`（`AuthenticationApple`）が担う。
public struct AppleSignInButton: View {
    @Environment(\.authenticationStore) private var store
    @State private var isLoading = false

    private let style: ASAuthorizationAppleIDButton.Style
    private let onError: (@MainActor (any Error) -> Void)?

    public init(
        style: ASAuthorizationAppleIDButton.Style = .black,
        onError: (@MainActor (any Error) -> Void)? = nil
    ) {
        self.style = style
        self.onError = onError
    }

    public var body: some View {
        AppleIDButtonRepresentable(style: style) {
            signIn()
        }
        .frame(height: 56)
        .disabled(store == nil || isLoading)
        .overlay {
            if isLoading {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.3))
                    .overlay { ProgressView().tint(.white) }
            }
        }
    }

    private func signIn() {
        guard let store else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await store.signIn(using: .apple)
            } catch let error as AuthError where error.code == .cancelled {
                // ユーザーキャンセルは無視
            } catch {
                onError?(error)
            }
        }
    }
}

// MARK: - Official Apple button bridge

#if canImport(UIKit)
import UIKit

private struct AppleIDButtonRepresentable: UIViewRepresentable {
    let style: ASAuthorizationAppleIDButton.Style
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: style)
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
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeNSView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: style)
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
