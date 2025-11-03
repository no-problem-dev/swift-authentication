# swift-authentication

Firebase Authentication、Google Sign-In、Apple Sign-In をサポートした Swift 製認証パッケージ

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![SPM](https://img.shields.io/badge/Swift_Package_Manager-compatible-brightgreen.svg)
![Firebase](https://img.shields.io/badge/Firebase-integrated-orange.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 概要

`swift-authentication` は、Swift アプリケーションで Firebase Authentication、Google Sign-In、Apple Sign-In を簡単に統合するためのパッケージです。iOS および macOS プラットフォームに対応し、モダンな async/await をサポートしています。

## 必要要件

- iOS 17.0+
- macOS 14.0+
- Swift 6.0+

## 依存関係

- [swift-general-domain](https://github.com/no-problem-dev/swift-general-domain) - 汎用ドメインモデル
- [swift-api-client](https://github.com/no-problem-dev/swift-api-client) - HTTP API クライアント
- [Firebase iOS SDK](https://github.com/firebase/firebase-ios-sdk) - Firebase Authentication
- [Google Sign-In](https://github.com/google/GoogleSignIn-iOS) - Google サインイン

## 前提条件

このパッケージを使用するには、以下の準備が必要です：

### 1. Firebase プロジェクトのセットアップ

1. [Firebase Console](https://console.firebase.google.com) で新しいプロジェクトを作成
2. Firebase Authentication を有効化
3. 使用するプロバイダーを有効化：
   - Google Sign-In プロバイダー
   - Apple Sign-In プロバイダー (iOS のみ)

### 2. GoogleService-Info.plist の取得

1. Firebase Console からプロジェクトの設定を開く
2. iOS アプリを追加（まだの場合）
3. `GoogleService-Info.plist` をダウンロード
4. Xcode プロジェクトのルートに追加
5. アプリのターゲットに含まれていることを確認

### 3. URL スキームの設定（Google Sign-In 用）

`Info.plist` に Google Sign-In 用の URL スキームを追加：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- GoogleService-Info.plist の REVERSED_CLIENT_ID をコピー -->
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
        </array>
    </dict>
</array>
```

> **重要**: `REVERSED_CLIENT_ID` の値は `GoogleService-Info.plist` から取得してください。

### 4. Apple Sign-In の設定（iOS のみ）

Apple Sign-In を使用する場合：

1. Apple Developer で App ID に "Sign In with Apple" Capability を追加
2. Xcode の Signing & Capabilities で "Sign in with Apple" を追加

> **注意**: macOS では Apple Sign-In は利用できません。macOS では Google Sign-In のみ使用できます。

### 5. バックエンド API のセットアップ

**必須 API エンドポイント**: **POST `/auth/initialize`** (パスは任意)

このエンドポイントは、Firebase 認証後にユーザーをバックエンドに登録・初期化するために使用されます。

#### 必須レスポンス形式（JSON、camelCase）

```json
{
  "initialized": true,
  "message": "User initialized successfully"
}
```

#### 認証フロー

1. ユーザーが Google または Apple でサインイン（Firebase Authentication）
2. Firebase から ID トークンを取得
3. バックエンド API に `/auth/initialize` をリクエスト（Authorization ヘッダーに Bearer トークン）
4. バックエンドがユーザーを登録/初期化
5. アプリで認証完了

> **注意**: このパッケージは自動的に Authorization ヘッダーに Firebase ID トークンを付与します。バックエンド側でトークンの検証が必要です。

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

## クイックスタート

### 1. Firebase の初期化

アプリ起動時に Firebase を設定：

```swift
import SwiftUI
import Authentication

@main
struct MyApp: App {
    init() {
        // Firebase を初期化
        FirebaseConfigure.configure()
    }

    @State private var authState = AuthenticationState()

    var body: some Scene {
        WindowGroup {
            AuthenticatedRootView(authState: $authState) {
                // 認証済みの場合に表示されるコンテンツ
                MainContentView()
            } signInView: {
                // 未認証の場合に表示されるサインイン画面
                SignInView()
            }
        }
    }
}
```

### 2. サインイン画面の実装

```swift
import SwiftUI
import Authentication

struct SignInView: View {
    @Environment(\.authenticationUseCase) var authUseCase
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("ログイン")
                .font(.largeTitle)
                .bold()

            Button {
                Task {
                    await signInWithGoogle()
                }
            } label: {
                HStack {
                    Image(systemName: "person.circle.fill")
                    Text("Google でサインイン")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isLoading)

            if isLoading {
                ProgressView()
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }

    private func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        do {
            try await authUseCase.signInWithGoogle()
        } catch {
            errorMessage = "サインインに失敗しました: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
```

### 3. ユーザー情報へのアクセス

```swift
import SwiftUI
import Authentication

struct ProfileView: View {
    @Environment(\.authenticationState) var authState

    var body: some View {
        VStack {
            if let user = authState.currentUser {
                AsyncImage(url: user.photoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())

                Text(user.name ?? "名前なし")
                    .font(.title)

                if let email = user.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
```

### 4. サインアウト

```swift
Button("サインアウト") {
    Task {
        do {
            try await authUseCase.signOut()
        } catch {
            print("サインアウトエラー: \(error)")
        }
    }
}
```

## 使い方

### カスタム認証フロー

より細かい制御が必要な場合：

```swift
import Authentication

struct CustomAuthView: View {
    @Environment(\.authenticationUseCase) var authUseCase
    @State private var authState = AuthenticationState()

    var body: some View {
        VStack {
            // 認証状態に応じた UI
            if authState.isAuthenticated {
                authenticatedView
            } else {
                signInView
            }
        }
        .task {
            // 認証状態の監視を開始
            for await newState in authState.authenticationStateStream() {
                authState = newState
            }
        }
    }

    private var authenticatedView: some View {
        VStack {
            Text("ようこそ、\(authState.currentUser?.name ?? "ユーザー")さん")
            Button("サインアウト") {
                Task {
                    try? await authUseCase.signOut()
                }
            }
        }
    }

    private var signInView: some View {
        Button("Google でサインイン") {
            Task {
                try? await authUseCase.signInWithGoogle()
            }
        }
    }
}
```

### API リクエストでの認証トークン使用

```swift
import APIClient
import Authentication

// FirebaseAuthTokenProvider を使って認証トークンを取得
let tokenProvider = FirebaseAuthTokenProvider()

// API クライアントに設定
let apiClient = APIClientImpl(
    baseURL: URL(string: "https://api.example.com")!,
    authTokenProvider: tokenProvider
)

// リクエスト時に自動的に Authorization ヘッダーが追加されます
let endpoint = APIEndpoint(path: "/user/profile", method: .get)
let profile: UserProfile = try await apiClient.request(endpoint)
```

## 機能

- ✅ Firebase Authentication 統合
- ✅ Google Sign-In サポート（iOS / macOS）
- ✅ Apple Sign-In サポート（iOS のみ）
- ✅ モダンな async/await API
- ✅ SwiftUI Environment Values 対応
- ✅ 認証状態の管理
- ✅ iOS 17.0+ および macOS 14.0+ 対応

## ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。詳細は [LICENSE](LICENSE) ファイルをご覧ください。
