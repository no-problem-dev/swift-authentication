import SwiftUI
import Authentication

public extension EnvironmentValues {
    /// 認証セッションのステートホルダ。合成ルートで注入し、画面はこれを観測します。
    @Entry var authenticationStore: AuthenticationStore? = nil
}

public extension View {
    /// ``AuthenticationStore`` を Environment に注入します。
    func authenticationStore(_ store: AuthenticationStore) -> some View {
        environment(\.authenticationStore, store)
    }
}
