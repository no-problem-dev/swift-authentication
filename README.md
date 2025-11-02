# swift-authentication

Firebase Authentication と Google Sign-In をサポートした Swift 製認証パッケージ

## 概要

`swift-authentication` は、Swift アプリケーションで Firebase Authentication と Google Sign-In を簡単に統合するためのパッケージです。iOS および macOS プラットフォームに対応し、モダンな async/await をサポートしています。

## 必要要件

- iOS 17.0+
- macOS 14.0+
- Swift 6.0+

## 依存関係

- [swift-general-domain](https://github.com/no-problem-dev/swift-general-domain) - 汎用ドメインモデル
- [swift-api-client](https://github.com/no-problem-dev/swift-api-client) - HTTP API クライアント
- [Firebase iOS SDK](https://github.com/firebase/firebase-ios-sdk) - Firebase Authentication
- [Google Sign-In](https://github.com/google/GoogleSignIn-iOS) - Google サインイン

## インストール

### Swift Package Manager

`Package.swift` に以下を追加してください：

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-authentication.git", from: "1.0.0")
]
```

または Xcode で：
1. File > Add Package Dependencies
2. パッケージ URL を入力: `https://github.com/no-problem-dev/swift-authentication.git`
3. バージョンを選択: `1.0.0` 以降

## 使い方

### 基本的な使い方

```swift
import Authentication

// Firebase の設定
FirebaseConfigure.configure()

// 認証状態の監視
// AuthenticationState を使用して認証状態を管理

// Google Sign-In
// FirebaseAuthRepository を使用して認証処理を実行
```

### SwiftUI での使用例

```swift
import SwiftUI
import Authentication

struct ContentView: View {
    @Environment(\.authenticationState) var authState

    var body: some View {
        if authState.isAuthenticated {
            Text("ログイン済み")
        } else {
            Text("未ログイン")
        }
    }
}
```

## 機能

- ✅ Firebase Authentication 統合
- ✅ Google Sign-In サポート
- ✅ モダンな async/await API
- ✅ SwiftUI Environment Values 対応
- ✅ 認証状態の管理
- ✅ iOS および macOS 対応

## アーキテクチャ

このパッケージは以下の構造で設計されています：

- **Public**: 外部に公開される API とモデル
  - DI: 依存性注入と環境設定
  - Model: 公開モデル（AuthenticationState など）
- **Internal**: パッケージ内部の実装
  - Domain: ドメインモデルとリポジトリインターフェース
  - Repository: Firebase と API の実装
  - Service: 認証サービスロジック

## ライセンス

MIT License

Copyright (c) 2024 NOPROBLEM

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
