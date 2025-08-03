# タスク完了時チェックリスト

## コード変更・新機能実装完了時に必ず実施

### 1. テスト実行
```bash
# 全テスト実行（必須）
xcodebuild test -project RecRadiko2.xcodeproj -scheme RecRadiko2 -destination 'platform=macOS'
```
- [ ] 全てのテストが成功することを確認
- [ ] 新機能にはテストが書かれていることを確認

### 2. ビルド確認
```bash
# クリーンビルド
xcodebuild clean -project RecRadiko2.xcodeproj -scheme RecRadiko2
xcodebuild -project RecRadiko2.xcodeproj -scheme RecRadiko2 -configuration Debug build
```
- [ ] ビルドエラーがないことを確認
- [ ] 警告が増えていないことを確認

### 3. コード品質チェック
- [ ] 日本語コメントが適切に記載されている
- [ ] コーディング規約に準拠している
- [ ] 不要なprint文やデバッグコードが削除されている
- [ ] エラーハンドリングが適切に実装されている

### 4. 権限・設定確認
- [ ] 新機能に必要なentitlements権限が追加されている
- [ ] ネットワーク通信を追加した場合は権限を確認
- [ ] 設定ファイルの変更が正しく反映されている

### 5. 動作確認
```bash
# アプリケーション実行
xcodebuild -project RecRadiko2.xcodeproj -scheme RecRadiko2 -configuration Debug build && open build/Debug/RecRadiko2.app
```
- [ ] 実機での動作確認完了
- [ ] 既存機能への影響がないことを確認

### 6. Git操作
```bash
# 差分確認
git diff
git status

# コミット（日本語メッセージ必須）
git add .
git commit -m "機能実装: [実装内容の説明]"
```
- [ ] コミットメッセージが日本語で記載されている
- [ ] 変更内容が適切にコミットされている

## 重要な注意事項
- テストが失敗している場合は絶対にコミットしない
- コンパイルエラーや警告は必ず解決してからコミット
- 権限設定の変更後は必ずクリーンビルドを実行