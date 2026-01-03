# Changelog

このプロジェクトのすべての重要な変更は、このファイルに記録されます。

このフォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [Semantic Versioning](https://semver.org/lang/ja/) に準拠しています。

## [未リリース]

なし

## [1.1.7] - 2026-01-03

### 変更
- Swift 6.2対応
  - `APIExecutor` を `APIExecutable` に変更
  - `any APIClient` を `some APIExecutable` に変更
  - `@Entry` マクロを使用してEnvironment Valueを簡潔に定義
- MainActor対応
  - viewController取得をMainActor Taskでラップし、Concurrency安全性を向上
- コード整理
  - 冗長なコメントを削除
  - コードの可読性を向上

## [1.1.6] - 2025-11-13

### 変更
- Package.swift の依存関係バージョン指定を `.upToNextMajor(from:)` に明示的に変更
  - `from:` と機能的には同じだが、セマンティックバージョニングに基づくバージョン更新の意図を明確化
  - 変更対象: swift-api-client (1.0.0)、firebase-ios-sdk (12.5.0)、GoogleSignIn-iOS (9.0.0)、swift-docc-plugin (1.4.0)

## [1.1.5] - 2025-11-12

### 追加
- Firebase Authentication エミュレーターサポート
  - `Environment` enum を追加（`.production` / `.emulator(host:port:)`）
  - `FIREBASE_AUTH_EMULATOR_HOST` 環境変数の自動設定
  - RELEASEビルドでのエミュレーター使用を禁止（セキュリティ対策）
  - デフォルトエミュレーター設定: localhost:9099
- 初回起動時の自動サインアウト処理
  - アプリ削除後の再インストール時に Firebase Auth のキーチェーン永続化による自動ログイン状態を解除
  - UserDefaults で初回起動フラグを管理
  - 完全に透過的な処理（ユーザーは意識不要）

### 修正
- エミュレーター接続実装を改善
  - 環境変数設定（setenv）から `Auth.auth().useEmulator()` の明示的呼び出しに変更
  - iOS SDK で正しく動作する実装パターンに修正
- `FirebaseApp` 初期化順序を修正
  - `signOutOnFirstLaunchIfNeeded()` を `FirebaseApp.configure()` の後に移動
  - `FirebaseApp` 未初期化の場合の防御チェックを追加

### 設計方針
- Authentication のみを対象（Firestore、Storage は含まない）
- データアクセスは REST API 経由
- DEBUG/RELEASE で自動的に環境切り替え可能

## [1.1.4] - 2025-11-11

### ⚠️ 破壊的変更
- 認証UIを完全にリニューアルし、カスタマイズ可能な設計に刷新
- `AuthenticationView` を削除し、代わりに `GoogleSignInButton` と `AppleSignInButton` を提供
- `AuthenticatedRootView` の API を変更し、ViewBuilder パターンを採用

### 追加
- `GoogleSignInButton`: Google サインイン用の独立したボタンコンポーネント
  - ローディング状態の表示
  - エラーハンドリングコールバック
  - アクセシブルなデザイン
  - SwiftUI プレビュー付き
- `AppleSignInButton`: Apple サインイン用のボタンコンポーネント
  - iOS 専用（macOS では非サポート表示）
  - カスタマイズ可能なスタイル（.black, .white, .whiteOutline）
  - ローディングオーバーレイ
  - SwiftUI プレビュー付き
- Google ロゴアセット（1x, 2x, 3x）を Asset Catalog として追加
- すべてのコンポーネントに包括的な SwiftUI プレビューを追加

### 変更
- `AuthenticatedRootView` を 4 つの ViewBuilder パラメータに変更：
  - `loading`: ローディング中・初期化中の表示（認証確認と初期化の両方で使用）
  - `unauthenticated`: 未認証時の表示（サインイン画面）
  - `error`: エラー発生時の表示
  - `authenticated`: 認証完了後の表示（メインコンテンツ）
- 各ボタンのデザインを統一されたアウトラインスタイルに変更し、視覚的な一貫性を向上
- Package.swift にリソース処理を追加（Asset Catalog サポート）

### 削除
- `AuthenticationView`: 完全にカスタマイズ可能な設計に置き換え

### 設計思想
- パッケージは認証ロジックと基本的なボタン UI のみを提供
- スプラッシュ画面、サインイン画面のレイアウト、利用規約、プライバシーポリシーの配置などは、アプリ側で完全にカスタマイズ可能
- ViewBuilder パターンにより、各認証状態に対して任意の UI を差し込み可能

## [1.1.3] - 2025-11-09

### 修正
- 自動リリースワークフローのメッセージを完全に日本語に統一（PRディスクリプション、リリースノート、ログメッセージ）

## [1.1.2] - 2025-11-04

### 追加
- DocC ドキュメントの自動生成と GitHub Pages への公開機能を追加
  - Swift DocC Plugin を依存関係に追加
  - GitHub Actions ワークフローで自動的にドキュメントを生成・デプロイ
  - README に完全なドキュメントへのリンクを追加 (https://no-problem-dev.github.io/swift-authentication/documentation/authentication/)

### 変更
- ドキュメントへのアクセシビリティを向上

## [1.0.3] - 2025-02-11

### 追加
- README にバックエンド API 前提条件セクションを追加
  - 必須 POST `/auth/initialize` エンドポイントを文書化
  - 必須 JSON レスポンス形式を camelCase で明記
  - Firebase 認証とバックエンド統合の認証フローを説明
  - Authorization ヘッダーが自動的に Firebase ID トークンで設定されることを明記

## [1.0.2] - 2025-02-11

### 改善
- README を簡潔化し、重要な情報のみに絞る
  - トラブルシューティングセクションを削除（Google Sign-In、トークンリフレッシュ、ビルドエラー）
  - アーキテクチャセクションを削除（内部実装の詳細）
  - パッケージ利用者にとって必須の情報のみを保持

## [1.0.1] - 2025-02-11

### 改善
- README に包括的なセットアップガイドとバッジを追加
  - Swift 6.0、プラットフォーム、SPM、Firebase、ライセンスのバッジを追加
  - 包括的な前提条件セクションを追加（Firebase セットアップ、GoogleService-Info.plist、URL スキーム）
  - 4 ステップの実装ガイドを含むクイックスタートセクションを追加
  - 詳細なサインイン画面の実装例を追加
  - ユーザープロフィールへのアクセスとサインアウトの例を追加
  - カスタム認証フローの例を追加
  - FirebaseAuthTokenProvider を使用した API リクエスト統合の例を追加
  - 一般的な問題のトラブルシューティングセクションを追加
  - 内部構造の詳細を含むアーキテクチャセクションを拡張
  - LICENSE ファイルへの参照を追加

## [1.0.0] - 2024-12-XX

### 追加
- 初回リリース
- Firebase Authentication 統合
- Google Sign-In サポート
- モダンな async/await API
- SwiftUI Environment Values 対応
- 認証状態の管理
- iOS 17.0+ および macOS 14.0+ サポート

[未リリース]: https://github.com/no-problem-dev/swift-authentication/compare/v1.1.7...HEAD
[1.1.7]: https://github.com/no-problem-dev/swift-authentication/compare/v1.1.6...v1.1.7
[1.1.6]: https://github.com/no-problem-dev/swift-authentication/compare/v1.1.5...v1.1.6
[1.1.5]: https://github.com/no-problem-dev/swift-authentication/compare/v1.1.4...v1.1.5
[1.1.4]: https://github.com/no-problem-dev/swift-authentication/compare/v1.1.3...v1.1.4
[1.1.3]: https://github.com/no-problem-dev/swift-authentication/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/no-problem-dev/swift-authentication/compare/v1.0.3...v1.1.2

<!-- Auto-generated on 2025-11-09T05:08:08Z by release workflow -->

<!-- Auto-generated on 2025-11-10T22:26:25Z by release workflow -->

<!-- Auto-generated on 2025-11-12T14:33:26Z by release workflow -->

<!-- Auto-generated on 2025-11-13T00:46:32Z by release workflow -->

<!-- Auto-generated on 2026-01-03T00:20:28Z by release workflow -->
