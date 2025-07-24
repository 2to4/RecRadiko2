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