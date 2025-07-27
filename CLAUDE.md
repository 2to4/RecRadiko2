# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

RecRadiko2は、Radiko（日本のインターネットラジオサービス）の録音を目的としたmacOS SwiftUIアプリケーションです。以下の技術スタックを使用しています：
- **言語**: Swift 5.0
- **UIフレームワーク**: SwiftUI
- **プラットフォーム**: macOS 15.5以上
- **IDE**: Xcode 16.4

## 🚨 **開発ルール**

### 基本方針
- **常に日本語で返答**: すべての開発作業・コミュニケーションは日本語で実施
- **日本語コミットメッセージ**: すべてのGitコミットメッセージは日本語で記述
- **テスト駆動開発**: t_wadaのテスト駆動手法を厳格に適用

### テスト駆動開発（TDD）手法
**t_wadaのテスト駆動開発定義に従い、以下の手順を厳守：**

1. **テストリスト作成**: 網羅したいテストシナリオのリストを書く
2. **Red（失敗）**: テストリストから「ひとつだけ」選び出し、実際に、具体的で、実行可能なテストコードに翻訳し、テストが失敗することを確認する
3. **Green（成功）**: プロダクトコードを変更し、いま書いたテスト（と、それまでに書いたすべてのテスト）を成功させる（その過程で気づいたことはテストリストに追加する）
4. **Refactor（改善）**: 必要に応じてリファクタリングを行い、実装の設計を改善する
5. **Repeat（繰り返し）**: テストリストが空になるまでステップ2に戻って繰り返す

### 必須開発手順
1. **コード変更前**: 既存テストが全て成功していることを確認
2. **新機能実装時**: TDD手法でテストケース先行作成・実装
3. **コード変更後**: 必ずテスト実行・成功確認
4. **テスト失敗時**: 新しいコードはコミット・使用禁止
5. **コミット時**: 必ず日本語でコミットメッセージを記述

### テスト実装方針
- **実環境優先**: 実際のファイル・設定・暗号化処理を使用
- **統合テスト重視**: 包括的統合テストによる品質保証
- **モック使用制限**: 外部API・システム操作・UI入力のみ（10%以下）

## 必須コマンド

### ビルド
```bash
# Debugビルド
xcodebuild -project RecRadiko2.xcodeproj -scheme RecRadiko2 -configuration Debug build

# Releaseビルド
xcodebuild -project RecRadiko2.xcodeproj -scheme RecRadiko2 -configuration Release build

# クリーンビルド
xcodebuild clean -project RecRadiko2.xcodeproj -scheme RecRadiko2
```

### テスト
```bash
# 全テスト実行（ユニットテスト + UIテスト）
xcodebuild test -project RecRadiko2.xcodeproj -scheme RecRadiko2 -destination 'platform=macOS'

# ユニットテストのみ実行
xcodebuild test -project RecRadiko2.xcodeproj -scheme RecRadiko2Tests -destination 'platform=macOS'
```

### 実行
```bash
# ビルドして実行
xcodebuild -project RecRadiko2.xcodeproj -scheme RecRadiko2 -configuration Debug build && open build/Debug/RecRadiko2.app
```

## プロジェクト構造

### ディレクトリ構成
```
RecRadiko2/
├── RecRadiko2.xcodeproj/      # Xcodeプロジェクト設定
├── RecRadiko2/                # メインアプリケーションソース
│   ├── RecRadiko2App.swift    # @mainアプリエントリーポイント
│   ├── ContentView.swift      # メインUI画面
│   ├── Assets.xcassets/       # 画像、カラー、アプリアイコン
│   └── RecRadiko2.entitlements # アプリサンドボックス権限
├── RecRadiko2Tests/           # ユニットテスト（Swift Testingフレームワーク）
└── RecRadiko2UITests/         # UIテスト（XCTestフレームワーク）
```

### 主要な技術仕様
- **Bundle ID**: com.futo4.app.RecRadiko2
- **アプリサンドボックス**: 読み取り専用ファイルアクセスで有効
- **コード署名**: ハードンドランタイムで自動署名
- **テスト**: ユニットテストには新しいSwift Testingフレームワーク、UIテストにはXCTestを使用

### 開発上の注意点
- 外部依存関係なし（CocoaPods、SPM、Carthageは未使用）
- リンターツール未設定（SwiftLintの導入を検討）
- コード品質のための厳格なコンパイラ警告を有効化
- 開発はXcodeまたはxcodebuildコマンドラインツールを使用

## 🔧 **追加開発ルール**

### 外部API連携開発ルール
1. **先行テスト実装**: 外部API連携前に独立したテストスクリプト作成
2. **設定統一**: テストスクリプトと本実装で完全同一の設定使用
3. **認証フロー検証**: auth1→auth2の段階的認証を個別に確認
4. **エラーハンドリング**: 各APIレスポンスで適切なエラー処理実装
5. **ログ出力**: 認証・API呼び出しの詳細ログを必ず実装

### macOSアプリ権限設定ルール
1. **entitlements確認**: 新機能実装前に必要な権限を事前確認
2. **ネットワーク権限**: HTTP通信使用時は必ずネットワーク権限を追加
   ```xml
   <key>com.apple.security.network.client</key>
   <true/>
   <key>com.apple.security.network.server</key>
   <true/>
   ```
3. **サンドボックス対応**: ファイルアクセス・ネットワークアクセスの権限設定確認
4. **権限テスト**: 権限変更後は必ずクリーンビルド・実機テスト実施

### HTTP通信実装ルール
1. **プロトコル分離**: HTTPClientProtocolで抽象化、Mock/Real実装分離
2. **ヘッダー統一**: User-Agent、認証ヘッダーは設定ファイルで一元管理
3. **レスポンス処理**: HTTPURLResponseのヘッダーは大文字小文字を考慮
4. **エラー処理**: ネットワークエラー・HTTPエラー・レスポンス解析エラーを分離
5. **タイムアウト設定**: 適切なタイムアウト値設定（デフォルト30秒）

### デバッグ・トラブルシューティング手順
1. **段階的確認**: Mock→独立テスト→実装の順で動作確認
2. **ログ出力**: 認証トークン・API URL・レスポンスの詳細ログ
3. **比較検証**: 動作するテストコードと実装の設定比較
4. **権限確認**: ネットワークエラー時はentitlements権限を最優先確認
5. **ビルド確認**: エラー解決後は必ずクリーンビルド実行

### 段階的開発・問題解決手順
1. **最小単位実装**: 一つの機能ずつ段階的に実装・テスト
2. **動作確認**: 各段階で必ず動作確認・スクリーンショット取得
3. **問題分離**: 複数問題発生時は一つずつ順序立てて解決
4. **設定統一**: 動作するテストコードの設定を本実装に適用
5. **回帰テスト**: 修正後は既存機能に影響がないことを確認

### コンパイルエラー対応ルール
1. **スコープ確認**: 変数のスコープ・ライフサイクルを適切に管理
2. **型安全**: Optional型・エラーハンドリングを適切に実装
3. **リファクタリング**: エラー修正時はコード品質も同時に改善
4. **テスト実行**: コンパイルエラー修正後は全テスト実行で回帰確認