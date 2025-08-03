# RecRadiko2 開発用コマンド一覧

## ビルドコマンド
```bash
# Debugビルド
xcodebuild -project RecRadiko2.xcodeproj -scheme RecRadiko2 -configuration Debug build

# Releaseビルド
xcodebuild -project RecRadiko2.xcodeproj -scheme RecRadiko2 -configuration Release build

# クリーンビルド
xcodebuild clean -project RecRadiko2.xcodeproj -scheme RecRadiko2
```

## テストコマンド
```bash
# 全テスト実行（ユニットテスト + UIテスト）
xcodebuild test -project RecRadiko2.xcodeproj -scheme RecRadiko2 -destination 'platform=macOS'

# ユニットテストのみ実行
xcodebuild test -project RecRadiko2.xcodeproj -scheme RecRadiko2Tests -destination 'platform=macOS'
```

## 実行コマンド
```bash
# ビルドして実行
xcodebuild -project RecRadiko2.xcodeproj -scheme RecRadiko2 -configuration Debug build && open build/Debug/RecRadiko2.app
```

## Git関連コマンド
```bash
# ステータス確認
git status

# 変更を確認
git diff

# ステージング
git add .

# コミット（日本語メッセージ必須）
git commit -m "機能追加: ○○機能の実装"
```

## Darwin/macOSユーティリティコマンド
```bash
# ファイル一覧
ls -la

# ディレクトリ移動
cd <directory>

# ファイル検索
find . -name "*.swift"

# テキスト検索（ripgrep推奨）
rg "検索パターン"

# プロセス確認
ps aux | grep RecRadiko2

# ログ確認
tail -f /var/log/system.log
```