import SwiftUI
import Authentication

/// Google Sign-In ボタン。
///
/// Google のブランドガイドラインに沿った意匠（公式ロゴ・白地・アウトライン）を持つ。
/// ロゴはこのターゲットのリソースにある本物で、`g.circle` のような似た記号で代用しない。
///
/// 押した後に何をするかは 2 通り（``AppleSignInButton`` と同じ形にしてある）:
///
/// - `init(title:onError:)` — `authenticationStore.signIn(using: .google)` を実行する。
/// - `init(title:perform:)` — 渡された処理を実行する。**セッションを自前で持つアプリ向け。**
public struct GoogleSignInButton: View {
    @Environment(\.authenticationStore) private var store
    @State private var isLoading = false

    private let title: String
    /// 押されたときに走らせるもの。nil のときだけ `authenticationStore` を使う。
    private let action: (@MainActor () async -> Void)?
    private let onError: (@MainActor (any Error) -> Void)?

    public init(
        title: String = "Google でログイン",
        onError: (@MainActor (any Error) -> Void)? = nil
    ) {
        self.title = title
        self.action = nil
        self.onError = onError
    }

    /// 押されたら `action` を実行する。ストアには触らない。
    public init(
        title: String = "Google でログイン",
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

    /// ストアを使う形のときだけ、ストアの不在で押せなくする。
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
            // ユーザーキャンセルは無視
        } catch {
            onError?(error)
        }
    }
}

/// Google Sign-In ボタン用の ButtonStyle。
///
/// `AppleSignInButton` のスタイルと視覚的に一貫したアウトライン表示を提供する。
/// カスタムの Google Sign-In ボタンを実装する場合にも利用できる。
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
