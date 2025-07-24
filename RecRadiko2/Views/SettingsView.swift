//
//  SettingsView.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import SwiftUI

/// 設定画面
struct SettingsView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel = SettingsViewModel()
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            // ファイル保存場所セクション
            fileLocationSection
            
            // ラジコプレミアムセクション  
            premiumSection
            
            // 利用可能容量表示
            storageInfoSection
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.appSecondaryBackground)
        .frame(minWidth: 800, minHeight: 600)
        .fileImporter(
            isPresented: $viewModel.showingDirectoryPicker,
            allowedContentTypes: [.folder]
        ) { result in
            switch result {
            case .success(let url):
                viewModel.updateSaveDirectory(url)
            case .failure(let error):
                viewModel.showError("フォルダの選択に失敗しました: \(error.localizedDescription)")
            }
        }
        .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Subviews
    /// ファイル保存場所セクション
    private var fileLocationSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("ファイル保存場所")
                .font(.appHeadline)
                .foregroundColor(.appPrimaryText)
            
            HStack(spacing: 16) {
                Button("変更") {
                    viewModel.selectSaveDirectory()
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("保存先フォルダを変更")
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.displayDirectoryPath)
                        .font(.appBody)
                        .foregroundColor(viewModel.isDirectoryValid ? .appPrimaryText : .appDanger)
                    
                    if !viewModel.isDirectoryValid {
                        Text("⚠️ ディレクトリが存在しません")
                            .font(.appCaption)
                            .foregroundColor(.appDanger)
                    }
                }
            }
        }
    }
    
    /// ラジコプレミアムセクション
    private var premiumSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("ラジコプレミアムサービス会員設定")
                .font(.appHeadline)
                .foregroundColor(.appPrimaryText)
            
            Text("※ プレミアム認証機能は将来実装予定です")
                .font(.appCaption)
                .foregroundColor(.appWarning)
            
            HStack(spacing: 30) {
                // ラベル列
                VStack(alignment: .trailing, spacing: 15) {
                    Text("登録メールアドレス")
                        .font(.appBody)
                        .foregroundColor(.appSecondaryText)
                        .frame(width: 140, alignment: .trailing)
                    
                    Text("パスワード")
                        .font(.appBody)
                        .foregroundColor(.appSecondaryText)
                        .frame(width: 140, alignment: .trailing)
                }
                
                // 入力欄列
                VStack(alignment: .leading, spacing: 15) {
                    TextField("", text: $viewModel.premiumEmail)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(5)
                        .frame(width: 280)
                        .background(Color.appInputBackground)
                        .cornerRadius(3)
                        .foregroundColor(.appPrimaryText)
                        .disabled(true) // Phase 1では無効
                        .accessibilityLabel("プレミアムメールアドレス")
                    
                    SecureField("", text: $viewModel.premiumPassword)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(5)
                        .frame(width: 280)
                        .background(Color.appInputBackground)
                        .cornerRadius(3)
                        .foregroundColor(.appPrimaryText)
                        .disabled(true) // Phase 1では無効
                        .accessibilityLabel("プレミアムパスワード")
                }
                
                // ボタン列
                VStack {
                    Button("設定 & 確認") {
                        viewModel.testPremiumConnection()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(viewModel.isTestingPremiumConnection)
                    .accessibilityLabel("プレミアム設定を確認")
                    
                    if viewModel.isTestingPremiumConnection {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                            .scaleEffect(0.8)
                    }
                }
            }
        }
    }
    
    /// ストレージ情報セクション
    private var storageInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("ストレージ情報")
                .font(.appHeadline)
                .foregroundColor(.appPrimaryText)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("利用可能容量:")
                        .font(.appBody)
                        .foregroundColor(.appSecondaryText)
                    
                    Text(viewModel.availableSpaceString)
                        .font(.appBody)
                        .foregroundColor(.appPrimaryText)
                }
                
                HStack {
                    Text("録音容量の目安:")
                        .font(.appBody)
                        .foregroundColor(.appSecondaryText)
                    
                    Text("1時間番組 約144MB")
                        .font(.appBody)
                        .foregroundColor(.appSecondaryText)
                }
                
                if !viewModel.hasEnoughSpaceForRecording() {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.appWarning)
                        
                        Text("容量不足: 録音には最低864MB必要です")
                            .font(.appCaption)
                            .foregroundColor(.appWarning)
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
}