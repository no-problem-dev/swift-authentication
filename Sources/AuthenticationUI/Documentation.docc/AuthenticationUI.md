# ``AuthenticationUI``

認証状態に応じて画面を切り替える SwiftUI コンポーネント集。

## Overview

`AuthenticationUI` は `Authentication` モジュールの ``AuthenticationStore`` を
SwiftUI の Environment 経由で受け取り、認証状態に応じた UI を宣言的に構築するためのコンポーネントを提供する。
サードパーティ SDK への依存はなく、システムフレームワーク（SwiftUI・AuthenticationServices）のみを使用する。

アプリのルートビューに ``AuthenticatedRootView`` を配置し、`.authenticationStore(_:)` モディファイアで
合成ルートから ``AuthenticationStore`` を注入するのが基本パターン。

```swift
import SwiftUI
import Authentication
import AuthenticationUI

@main
struct MyApp: App {
    // ダミー: 実際には AuthenticationFirebase 等の具象を渡す
    let store = AuthenticationStore(authenticator: myAuthenticator)

    var body: some Scene {
        WindowGroup {
            AuthenticatedRootView(
                loading: { ProgressView() },
                unauthenticated: {
                    VStack(spacing: 16) {
                        AppleSignInButton()
                        GoogleSignInButton(title: "Google でログイン")
                    }
                    .padding(.horizontal, 32)
                },
                error: { error in
                    Text("エラー: \(error.localizedDescription)")
                },
                authenticated: { user in
                    HomeView(user: user)
                }
            )
            .authenticationStore(store)
        }
    }
}
```

``AppleSignInButton`` と ``GoogleSignInButton`` は Environment から ``AuthenticationStore`` を
読み取り、タップ時に対応する `signIn(using:)` を自動で呼び出す。
エラーハンドリングは `onError` クロージャで受け取れる（ユーザーキャンセルは自動的に無視される）。

## Topics

### ルートビュー

- ``AuthenticatedRootView``

### サインインボタン

- ``AppleSignInButton``
- ``GoogleSignInButton``
- ``GoogleSignInButtonStyle``
