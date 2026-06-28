import SwiftUI
import Authentication

/// Google Sign-In ボタン。
///
/// タップで `authenticationStore.signIn(using: .google)` を実行する。資格情報の取得は
/// 合成ルートで注入された `GoogleCredentialProvider`（`AuthenticationGoogle`）が担う。
public struct GoogleSignInButton: View {
    @Environment(\.authenticationStore) private var store
    @State private var isLoading = false

    private let title: String
    private let onError: (@MainActor (any Error) -> Void)?

    public init(
        title: String = "Google でログイン",
        onError: (@MainActor (any Error) -> Void)? = nil
    ) {
        self.title = title
        self.onError = onError
    }

    public var body: some View {
        Button(action: signIn) {
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
        .disabled(store == nil || isLoading)
    }

    private func signIn() {
        guard let store else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await store.signIn(using: .google)
            } catch let error as AuthError where error.code == .cancelled {
                // ユーザーキャンセルは無視
            } catch {
                onError?(error)
            }
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
