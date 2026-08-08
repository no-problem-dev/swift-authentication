import SwiftUI
import AuthenticationServices
import Authentication

/// Sign in with Apple ボタン。
///
/// 公式の `ASAuthorizationAppleIDButton` を表示する。**Apple の意匠は自作しない** ——
/// ロゴ・文言・角丸・最小サイズ・余白のすべてに規定があり、SF Symbol の `apple.logo` を
/// 並べたリスト行は Sign in with Apple ボタンとして認められない（審査で落ちる）。
/// このボタンが存在する理由は、その意匠をアプリ側に書かせないこと。
///
/// 押した後に何をするかは 2 通りある:
///
/// - `init(style:onError:)` — `authenticationStore.signIn(using: .apple)` を実行する。
///   資格情報の取得は合成ルートで注入された `AppleCredentialProvider`（`AuthenticationApple`）が担う。
/// - `init(style:perform:)` — 渡された処理を実行する。**セッションを自前で持つアプリ向け。**
///   匿名アカウントの昇格（link）のように、このパッケージのストアに無い遷移を扱うことがある。
///   意匠だけを借りたい側が、意匠を書き写さずに済むようにする。
public struct AppleSignInButton: View {
    @Environment(\.authenticationStore) private var store
    @State private var isLoading = false

    private let style: ASAuthorizationAppleIDButton.Style
    /// ボタンの文言（「Apple でサインイン」/「Apple で続ける」/「Apple で登録」）。
    ///
    /// **並べる相手に合わせる。** 登録とサインインを人に選ばせないアプリでは、
    /// 隣の Google が「つづける」なのにこちらだけ「サインイン」だと、
    /// **押す前に違うことが起きると読まれる**（実際にそう報告された）。
    /// Apple が用意している 3 つの文言はこのためにある。
    private let type: ASAuthorizationAppleIDButton.ButtonType
    /// 押されたときに走らせるもの。nil のときだけ `authenticationStore` を使う。
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

    /// 押されたら `action` を実行する。ストアには触らない（`authenticationStore` が無くても押せる）。
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

    /// ストアを使う形のときだけ、ストアの不在で押せなくする。
    /// `action` を渡された形はストアを見ないので、無いことは押せない理由にならない。
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
            // ユーザーキャンセルは無視
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
