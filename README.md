# swift-authentication

Firebase Authentication、Google Sign-In、Apple Sign-In をサポートした Swift 製認証パッケージ

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![SPM](https://img.shields.io/badge/Swift_Package_Manager-compatible-brightgreen.svg)
![Firebase](https://img.shields.io/badge/Firebase-integrated-orange.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

📚 **[完全なドキュメント](https://no-problem-dev.github.io/swift-authentication/documentation/authentication/)**

## 概要

`swift-authentication` は、Swift アプリケーションで Firebase Authentication、Google Sign-In、Apple Sign-In を簡単に統合するためのパッケージです。認証状態の管理のみに集中し、ユーザー情報の管理は行いません。

### 主な機能

- ✅ **Firebase Authentication 統合** - Firebase との完全な統合
- ✅ **Google Sign-In サポート** - iOS / macOS 対応
- ✅ **Apple Sign-In サポート** - iOS のみ
- ✅ **モダンな async/await API** - Swift 6.0 の並行処理機能をフル活用
- ✅ **SwiftUI Environment Values 対応** - SwiftUI と完全に統合
- ✅ **認証状態の管理に特化** - ユーザー情報は管理しないシンプルな設計
- ✅ **クロスプラットフォーム** - iOS 17.0+ および macOS 14.0+ 対応

## 必要要件

- iOS 17.0+
- macOS 14.0+
- Swift 6.0+

## 依存関係

- [swift-api-client](https://github.com/no-problem-dev/swift-api-client) - HTTP API クライアント
- [Firebase iOS SDK](https://github.com/firebase/firebase-ios-sdk) - Firebase Authentication
- [Google Sign-In](https://github.com/google/GoogleSignIn-iOS) - Google サインイン

## 前提条件

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
    .package(url: "https://github.com/no-problem-dev/swift-authentication.git", from: "1.1.0")
]
```

または Xcode で：
1. File > Add Package Dependencies
2. パッケージ URL を入力: `https://github.com/no-problem-dev/swift-authentication.git`
3. バージョンを選択: `1.1.0` 以降

## クイックスタート

### 1. Firebase の初期化と AuthenticationUseCase の設定

```swift
import SwiftUI
import Authentication
import APIClient

@main
struct MyApp: App {
    private let authUseCase: AuthenticationUseCase

    init() {
        // Firebase を初期化
        FirebaseConfigure.configure()

        // APIClient を作成
        let apiClient = APIClientImpl(
            baseURL: URL(string: "https://api.example.com")!,
            authTokenProvider: FirebaseAuthTokenProvider()
        )

        // AuthenticationUseCase を作成
        self.authUseCase = AuthenticationUseCaseImpl(
            apiClient: apiClient,
            authenticationPath: "/api/v1/auth/initialize"
        )
    }

    var body: some Scene {
        WindowGroup {
            AuthenticatedRootView(
                authenticationHeader: {
                    VStack {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 60))
                        Text("マイアプリ")
                            .font(.title)
                    }
                },
                authenticatedContent: {
                    MainContentView()
                }
            )
            .authenticationUseCase(authUseCase)
        }
    }
}
```

### 2. サインアウト

```swift
import SwiftUI
import Authentication

struct MainContentView: View {
    @Environment(\.authenticationUseCase) private var authUseCase

    var body: some View {
        VStack {
            Text("認証済みコンテンツ")
                .font(.title)

            Button("サインアウト") {
                Task {
                    try? await authUseCase?.signOut()
                }
            }
        }
    }
}
```

### 3. 認証状態の確認

```swift
import SwiftUI
import Authentication

struct SomeView: View {
    @Environment(\.authenticationUseCase) private var authUseCase
    @State private var isAuthenticated = false

    var body: some View {
        Text(isAuthenticated ? "認証済み" : "未認証")
            .task {
                isAuthenticated = await authUseCase?.isAuthenticated() ?? false
            }
    }
}
```

## 使い方

### 認証状態の監視

```swift
import Authentication

struct CustomAuthView: View {
    @Environment(\.authenticationUseCase) private var authUseCase
    @State private var authState: AuthenticationState = .checking

    var body: some View {
        Group {
            switch authState {
            case .checking:
                ProgressView("確認中...")
            case .unauthenticated:
                SignInView()
            case .firebaseAuthenticatedOnly:
                ProgressView("初期化中...")
            case .authenticated:
                MainContentView()
            case .error(let error):
                ErrorView(error: error)
            }
        }
        .task {
            guard let authUseCase = authUseCase else { return }
            for await state in authUseCase.observeAuthState() {
                authState = state
            }
        }
    }
}
```

### ユーザー情報の取得

認証パッケージはユーザー情報を管理しません。必要な場合は FirebaseAuth から直接取得してください：

```swift
import FirebaseAuth

// ユーザー ID の取得
if let userId = Auth.auth().currentUser?.uid {
    print("User ID: \(userId)")
}

// その他のユーザー情報
if let currentUser = Auth.auth().currentUser {
    let email = currentUser.email
    let displayName = currentUser.displayName
    let photoURL = currentUser.photoURL
}
```

または、バックエンド API から別途ユーザープロファイル情報を取得してください。

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

## 認証状態

`AuthenticationState` は以下の状態を持ちます：

- `.checking` - 認証状態を確認中
- `.unauthenticated` - 未認証
- `.firebaseAuthenticatedOnly` - Firebase 認証済み（バックエンド API 認証待ち）
- `.authenticated` - 完全認証済み
- `.error(Error)` - 認証エラー

## ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。詳細は [LICENSE](LICENSE) ファイルをご覧ください。

## サポート

問題が発生した場合や機能リクエストがある場合は、[GitHub の Issue](https://github.com/no-problem-dev/swift-authentication/issues) を作成してください。
