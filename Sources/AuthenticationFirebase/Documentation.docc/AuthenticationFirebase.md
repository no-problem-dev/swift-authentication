# ``AuthenticationFirebase``

Firebase Authentication によるセッション交換・トークン供給・初期化ユーティリティ。

## Overview

`AuthenticationFirebase` は ``Authentication/Authenticator`` プロトコルを Firebase で実装し、
vendor 非依存な ``Authentication/AuthCredential`` を Firebase 資格情報に変換してセッション交換を行います。
また、REST クライアントへ ID トークンを渡す ``Authentication/AuthTokenProviding`` の実装と、
Firebase の初期化ユーティリティも提供します。

アプリ起動時に ``FirebaseConfigurator/configure(environment:enableDebugMode:)`` を一度呼んでください。
開発環境では `.emulator` を指定すると Firebase Local Emulator Suite に接続できます。

```swift
import AuthenticationFirebase

// AppDelegate または @main 構造体の初期化時に一度だけ呼ぶ
// enableDebugMode は RELEASE では無効化すること（下記参照）
FirebaseConfigurator.configure(environment: .production)

// 開発時（デバッグビルドのみ使用可）
// FirebaseConfigurator.configure(environment: .emulator(host: "localhost", port: 9099))
```

``FirebaseAuthenticator`` と ``FirebaseTokenProvider`` は合成ルートで ``Authentication/AuthenticationStore`` へ注入します。

```swift
import Authentication
import AuthenticationFirebase

let authenticator = FirebaseAuthenticator()       // Auth.auth() を既定で使用
let tokenProvider = FirebaseTokenProvider()

let store = AuthenticationStore(authenticator: authenticator)
```

``FirebaseConfigurator/googleClientID`` を使うと、FirebaseCore に直接依存せずに
`GoogleService-Info.plist` 由来のクライアント ID を取得できます。

## Topics

### 初期化

- ``FirebaseConfigurator``
- ``FirebaseConfigurator/Environment``

### セッション交換

- ``FirebaseAuthenticator``

### トークン供給

- ``FirebaseTokenProvider``
