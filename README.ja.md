[English](./README.md) | 日本語

# swift-authentication

アプリのサーバーが発行するセッションでサインインする、iOS 向けのパッケージ。Apple と Google は本人を確かめる手段で、ユーザーの ID とトークンはアプリのサーバーが発行する。

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20%7C%20macOS%2014+-blue.svg)
![SPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 設計

- **セッションはアプリのサーバーが発行する。** アプリの Worker（`@studio/app-auth`）が、ユーザーの ID・24時間のアクセストークン・端末ごとのリフレッシュトークンを発行する。要求はすべてアプリの独自ドメインに送るので、外の会社の認証サービスに届くかどうかに左右されない（たとえば中国本土からは Google のエンドポイントに届かない）
- **Apple と Google は本人を確かめる手段。** 端末がそれぞれの ID トークンを送り、サーバーが公開キーで確かめて、今のアカウントにつなぐか、そのトークンが付いているアカウントでサインインする
- **Firebase はこのパッケージに含めない。** Firebase Authentication から移すアプリは、移し替えの間だけ [swift-authentication-firebase](https://github.com/no-problem-dev/swift-authentication-firebase) を使う。前のバージョンが端末に残したセッションをサーバーで交換し、ユーザーの ID をそのまま引き継ぐ

| 責務 | プロトコル（コア） | 具象（別ターゲット） |
|---|---|---|
| 資格情報の取得 | `CredentialProvider` | `AppleCredentialProvider` / `GoogleCredentialProvider` |
| セッション交換 | `Authenticator` | `SessionAuthenticator` |
| Bearer トークン | `AuthTokenProviding` | `SessionTokenProvider` |

これらを束ねる `@Observable` な **`AuthenticationStore`**（`@MainActor`）が `state` を公開し、画面はこれを観測する。サインインの後にアプリがすることは、アプリの責務とする。

### ターゲット構成

| ターゲット | 役割 | 外部依存 |
|---|---|---|
| **`Authentication`** | コア抽象（プロトコル・値型・`AuthenticationStore`） | **なし** |
| **`AuthenticationSession`** | アプリのサーバーのセッション：サインイン・つなぐ・再取得・キーチェーンへの保存・古いセッションの交換 | Foundation / Security（システム） |
| **`AuthenticationUI`** | SwiftUI ビュー + Environment DI | SwiftUI（システム） |
| **`AuthenticationApple`** | Apple 資格情報取得 | AuthenticationServices / CryptoKit（システム） |
| **`AuthenticationGoogle`** | Google 資格情報取得 | GoogleSignIn |

SDK に依存するのは `AuthenticationGoogle` だけ。画面は `Authentication` と `AuthenticationUI` だけに依存するので、SwiftUI プレビューはほかに何も読み込まない。

## 使い方

### 1. 合成ルートで `AuthenticationStore` を作る

```swift
import SwiftUI
import Authentication
import AuthenticationUI
import AuthenticationSession
import AuthenticationApple

@main
struct MyApp: App {
    @State private var store: AuthenticationStore
    private let authenticator: SessionAuthenticator

    init() {
        authenticator = SessionAuthenticator(
            baseURL: URL(string: "https://api.example.com")!,   // 独自ドメイン。workers.dev は使わない
            installID: { InstallID.current }                    // アプリが UserDefaults に持つ UUID
        )
        _store = State(initialValue: AuthenticationStore(
            authenticator: authenticator,
            credentialProviders: [AppleCredentialProvider()]
        ))
    }

    var body: some Scene {
        WindowGroup {
            AuthenticatedRootView(
                loading: { ProgressView() },
                unauthenticated: { ProgressView().task { try? await authenticator.establishSession() } },
                error: { error in Text(error.localizedDescription) },
                authenticated: { user in MainView(userID: user.id) }
            )
            .authenticationStore(store)
        }
    }
}
```

API クライアントは `authenticator.tokenProvider` から Bearer トークンを受け取る。

```swift
let token = try await authenticator.tokenProvider.requiredToken()
// 401 を受けたら1回だけ
let renewed = try await authenticator.tokenProvider.requiredToken(forceRefresh: true)
```

### 2. 画面（プレビュー可能・ベンダー非依存）

```swift
import SwiftUI
import Authentication
import AuthenticationUI

struct MainView: View {
    @Environment(\.authenticationStore) private var store
    let userID: String

    var body: some View {
        VStack {
            Text("Welcome, \(userID)")
            Button("Sign Out") { Task { try? await store?.signOut() } }
        }
    }
}

#Preview {
    MainView(userID: "preview")
        .authenticationStore(.previewUnauthenticated)
}
```

### 状態

`AuthenticationState` の遷移：

- `.checking` — 起動時に保存済みセッションを読んでいる
- `.unauthenticated` — セッションが無い
- `.authenticated(AuthUser)` — サインイン済み
- `.error(any Error)` — 交換に失敗した

### 起動時にセッションを確立する

`establishSession()` が、端末が誰としてサインインするかを決める。

1. 保存済みのセッションがあれば、それを使う。アクセストークンの期限が5分を切っていれば先に再取得する。再取得がサーバーに届かなくても、保存済みのセッションを使う
2. 無ければ、`LegacySessionSource` が前のバージョンのセッションを持っているとき、`/v1/auth/firebase` で交換する（持っている物に合わせて `{ idToken }` か `{ refreshToken }`）。ユーザーの ID は変わらない。**届かない・503 など、やり直せば通るかもしれない失敗では、セッションを作らない**（作ると、その人の記録から外れる）。エラーを投げるので、あとでもう一度呼ぶ。サーバーが「二度と替えられない」と答えたとき（410 `account_deleted`、または Google がリフレッシュトークンを断った 401 `invalid_firebase_refresh_token`）は、前のセッションを消して 3 に進む
3. どちらも無ければ、`/v1/auth/anonymous` で新しい匿名のセッションを作る。`SessionAuthenticator(…, anonymous: .disabled)`（サインインが任意のアプリ）では作らず、`AuthError.notAuthenticated` を投げる。Apple・Google でサインインするまでサインアウトのまま

`store.signIn(with: .anonymous)` も同じ手順を通る。同時に呼ばれたときは1回の試みを分け合う。

### トークン

`SessionTokenProvider` は、期限が5分を切る前に `/v1/auth/refresh` で再取得する。同時に来た再取得は1つにまとめ、`forceRefresh: true` なら必ず再取得する。サーバーがリフレッシュトークンを断ったら、端末からセッションを消し、`authStateChanges()` が `nil` を流し、`AuthError.notAuthenticated` を投げる。早めに再取得しようとしてサーバーに届かなかったときは、まだ使えるトークンを返す。要求のタイムアウトは、指定しなければ20秒（`requestTimeout:`）。

### 匿名アカウントを引き継ぐ

`signIn` はセッションを置き換えるので、匿名ユーザーが Apple でサインインすると新しいユーザー ID になり、匿名アカウントのデータから離れる。`link` は今のアカウントに資格情報をつなぎ、ID を保つ。

```swift
do {
    try await store.link(using: .apple)
} catch AuthError.credentialAlreadyInUse(let collision) {
    // このプロバイダのアカウントを既に持っている（多くは別の端末で作ったもの）。
    // 切り替えるとユーザー ID が変わるので、先に本人に確かめる。
    try await store.signIn(resolving: collision)
}
```

衝突は、衝突した資格情報そのものを持つ。サーバーはトークンを署名で確かめるので、`signIn(resolving:)` は Apple のシートを出し直さずに、同じトークンでオーナーのアカウントにサインインする。その間にトークンの期限が切れていれば、ストアがプロバイダのシートを出して新しく取る。別の人に切り替えたら、前のセッションの端末をサーバーで無効にする。

`unlink(_:)` はつないだ手段を外す（`DELETE /v1/auth/identities/:provider`）。ユーザー ID は変わらない。

### 持っているアカウントにサインインする

「持っているアカウントに入る」画面では `signInExisting` を使う。`mode: "sign_in_existing"` を送り、その資格情報のアカウントがあればサインインする。無ければ何も作らず、何もつながず、今のセッションもそのまま。

```swift
let found = try await store.signInExisting(using: .apple)
if !found { /* この Apple ID のアカウントはまだ無い */ }
```

切り替える前に本人に確かめたいとき（アカウントがあると分かってから確かめる）は `SessionAuthenticator.findExisting(with:)` を使う。`commit()` するまで端末のセッションは替わらない。

```swift
guard let pending = try await authenticator.findExisting(with: credential) else { return /* 見つからない */ }
if await confirmReplace(pending.user) {
    try await pending.commit()
} else {
    await pending.cancel()   // 切り替えのためにサーバーが出したセッションを無効にする
}
```

### 消したアカウント

消したアカウントには、サーバーが 410 `account_deleted` を返す。`AuthError.accountDeleted` として届く。消したアカウントの古いセッションは忘れ、代わりに新しい匿名のセッションを作る。

### サインアウト

`signOut()` はキーチェーンを先に消し、そのあと `/v1/auth/sign-out` で端末のキーの無効化をサーバーに頼む（届かなくてもよい）。オフラインでも動く。古いセッションも忘れるので、やり直すと古い人に戻らず、新しい匿名ユーザーになる。

### アカウントの削除

`store.deleteAccount()` は Bearer トークンを付けて `DELETE /v1/account`（`accountDeletionPath:` で変えられる）を送り、サーバーが成功してからセッションを消す。Apple につないだアカウントなら、先に Apple のシートを出して新しい認可コードを取り、`{ "appleAuthorizationCode": … }` として送る。サーバーはこれで Apple のトークンを無効にする（審査ガイドライン 5.1.1(v)）。コードは1回きりで、5分ほどで切れるので、削除のときに取る。シートを閉じたら何も消さず、`AuthError.cancelled` を投げる。

### 拡張とセッションを分け合う

`KeychainSessionStore` は `kSecAttrAccessibleAfterFirstUnlock` で保存する。ウィジェットと分け合うときはアクセスグループを渡す。

```swift
SessionAuthenticator(
    baseURL: apiURL,
    installID: { InstallID.current },
    store: KeychainSessionStore(accessGroup: "TEAMID.com.example.shared")
)
```

キーチェーンの項目はアプリを消しても残るので、同じ端末で入れ直すと同じユーザーに戻る。セッションとして読めない項目は勝手に消さず `KeychainSessionStore.UndecodableItem` を投げる（`signOut()` で消える）。テストとプレビューは `InMemorySessionStore` を使う。

### Firebase Authentication から移す

[swift-authentication-firebase](https://github.com/no-problem-dev/swift-authentication-firebase) を足し、`FirebaseKeychainLegacySessionSource` を渡す。Firebase Authentication がキーチェーンに残したリフレッシュトークンを Firebase の SDK なしで読み、サーバーが Google で替える。

```swift
import AuthenticationFirebase

SessionAuthenticator(
    baseURL: apiURL,
    installID: { InstallID.current },
    legacySource: FirebaseKeychainLegacySessionSource(googleAppID: "1:1234567890:ios:abcdef")
)
```

交換は1回だけで、サーバーは Firebase の uid をそのままユーザー ID にする。交換の後はキーチェーンの項目を消す。Firebase を使ったことのないアプリは、このパッケージを入れない。

### 独自プロバイダ

`AuthProviderID` は拡張可能。`CredentialProvider` か `Authenticator` を実装すれば、ほかの手段も差し込める。

## ドキュメント

各モジュールの API リファレンスは [`Sources/`](Sources) 以下の各モジュールにある DocC カタログ。

## インストール

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-authentication.git", from: "12.0.0")
]
```

ターゲットに必要なプロダクトだけを追加する。

- 画面モジュール → `AuthenticationUI`（+ `Authentication`）
- 合成ルート（App ターゲット）→ `AuthenticationSession` / `AuthenticationApple` / `AuthenticationGoogle`

10.x から移すときは [CHANGELOG.md](CHANGELOG.md) を見る。

## 動作環境

| Swift | プラットフォーム |
|---|---|
| 6.2 | iOS 17+ · macOS 14+ |

## ライセンス

MIT License。詳細は [LICENSE](LICENSE) を参照。
