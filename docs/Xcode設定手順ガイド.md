# Xcode設定手順ガイド

## 📱 プロジェクト設定の場所

### 1. プロジェクトナビゲータを開く
1. Xcodeを起動し、RecRadiko2プロジェクトを開く
2. 左側のナビゲータエリアで「プロジェクトナビゲータ」タブを選択（フォルダアイコン、または `⌘+1`）

### 2. プロジェクト設定を開く
1. プロジェクトナビゲータの最上部にある **「RecRadiko2」（青いアイコン）** をクリック
2. 中央のエディタエリアにプロジェクト設定が表示される

## 🔐 Signing & Capabilities設定

### 場所
1. エディタエリアの上部にある **「RecRadiko2」ターゲット** を選択
2. タブバーから **「Signing & Capabilities」** タブをクリック

### 設定項目
```
┌─────────────────────────────────────────────┐
│ Signing & Capabilities                      │
├─────────────────────────────────────────────┤
│ Signing                                     │
│ ┌───────────────────────────────────────┐   │
│ │ ☑ Automatically manage signing        │   │
│ │                                       │   │
│ │ Team: [ドロップダウンメニュー]          │   │
│ │ Bundle Identifier: com.futo4.app...   │   │
│ │ Signing Certificate: Apple Development│   │
│ └───────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

### 具体的な設定手順

#### 1. Apple IDの追加（未設定の場合）
1. Xcode メニューバー → **「Xcode」** → **「Settings...」**（または `⌘+,`）
2. **「Accounts」** タブをクリック
3. 左下の **「+」** ボタンをクリック
4. **「Apple ID」** を選択し、Apple IDとパスワードでログイン

#### 2. Team設定
1. Signing & Capabilities画面で **「Team」** ドロップダウンをクリック
2. 以下のいずれかを選択：
   - **個人開発者**: 「Your Name (Personal Team)」
   - **組織開発者**: 「Organization Name (Team ID)」

#### 3. Bundle Identifier確認
- 自動的に設定される値: `com.futo4.app.RecRadiko2`
- 変更不要（既に正しく設定済み）

#### 4. Automatically manage signing
- ☑ チェックボックスが**オン**になっていることを確認
- これにより証明書とプロビジョニングプロファイルが自動管理される

## 🧪 UITestsターゲットの設定

同じ設定をUITestsターゲットにも適用：

1. エディタエリア上部で **「RecRadiko2UITests」** ターゲットを選択
2. **「Signing & Capabilities」** タブをクリック
3. 同じTeamを選択
4. Automatically manage signingをオン

## ✅ 設定確認方法

### 1. ビルド確認
```bash
# ビルドのみ（エラーチェック）
⌘+B (Command+B)
```

### 2. テスト実行確認
```bash
# テスト実行
⌘+U (Command+U)
```

### 3. 証明書確認
プロジェクト設定の「Signing」セクションで：
- ✅ エラーや警告が表示されていない
- ✅ 「Signing Certificate」に「Apple Development」が表示
- ✅ 「Provisioning Profile」に「Xcode Managed Profile」が表示

## 🚨 よくある問題と解決方法

### 「No account for team」エラー
1. Xcode → Settings → Accounts でApple IDを追加
2. プロジェクト設定でTeamを再選択

### 「Failed to register bundle identifier」エラー
1. Bundle Identifierを一意の値に変更
   例: `com.yourname.RecRadiko2`

### 「Revoke certificate」警告
1. 「Fix Issue」ボタンをクリック
2. Xcodeが自動的に新しい証明書を生成

## 📍 設定場所の視覚的ガイド

```
Xcode ウィンドウ構造：
┌────────────────────────────────────────────────────┐
│ メニューバー (Xcode > Settings でアカウント設定)      │
├────────────────────────────────────────────────────┤
│ ┌──────────┬────────────────────────────────────┐ │
│ │Navigator │  エディタエリア                      │ │
│ │          │ ┌─────────────────────────────────┐ │ │
│ │RecRadiko2│ │ TARGET: RecRadiko2             │ │ │
│ │(青アイコン)│ │ [General][Signing & Capabilities]│ │ │
│ │          │ │                               │ │ │
│ │          │ │ ☑ Automatically manage signing │ │ │
│ │          │ │ Team: [選択]                   │ │ │
│ │          │ └─────────────────────────────────┘ │ │
│ └──────────┴────────────────────────────────────┘ │
└────────────────────────────────────────────────────┘
```

## 🎯 設定完了チェックリスト

- [ ] Xcode > Settings > Accounts でApple IDログイン完了
- [ ] プロジェクトナビゲータでRecRadiko2（青アイコン）を選択
- [ ] RecRadiko2ターゲットを選択
- [ ] Signing & Capabilitiesタブを開いている
- [ ] Teamが選択されている
- [ ] Automatically manage signingがオン
- [ ] エラーや警告が表示されていない
- [ ] RecRadiko2UITestsターゲットも同様に設定完了