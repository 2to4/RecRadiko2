//
//  LoadingView.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import SwiftUI

/// ローディング表示コンポーネント
struct LoadingView: View {
    // MARK: - Properties
    let message: String
    
    // MARK: - Initializer
    init(message: String = "読み込み中...") {
        self.message = message
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                .scaleEffect(1.2)
            
            Text(message)
                .font(.appBody)
                .foregroundColor(.appSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.opacity(0.8))
        .accessibilityLabel(message)
    }
}

/// インライン ローディング表示コンポーネント
struct InlineLoadingView: View {
    // MARK: - Properties
    let message: String
    
    // MARK: - Initializer
    init(message: String = "読み込み中...") {
        self.message = message
    }
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                .frame(width: 16, height: 16)
            
            Text(message)
                .font(.appBody)
                .foregroundColor(.appSecondaryText)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(message)
    }
}

/// 空状態表示コンポーネント
struct EmptyStateView: View {
    // MARK: - Properties
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    // MARK: - Initializer
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.appSecondaryText)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.appHeadline)
                    .foregroundColor(.appPrimaryText)
                
                Text(message)
                    .font(.appBody)
                    .foregroundColor(.appSecondaryText)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle,
               let action = action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// エラー表示コンポーネント
struct ErrorView: View {
    // MARK: - Properties
    let message: String
    let retryAction: (() -> Void)?
    
    // MARK: - Initializer
    init(message: String, retryAction: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retryAction
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.appDanger)
            
            VStack(spacing: 8) {
                Text("エラーが発生しました")
                    .font(.appHeadline)
                    .foregroundColor(.appPrimaryText)
                
                Text(message)
                    .font(.appBody)
                    .foregroundColor(.appSecondaryText)
                    .multilineTextAlignment(.center)
            }
            
            if let retryAction = retryAction {
                Button("再試行") {
                    retryAction()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        LoadingView()
            .frame(height: 200)
        
        Divider()
        
        InlineLoadingView(message: "番組表を読み込み中...")
        
        Divider()
        
        EmptyStateView(
            icon: "radio",
            title: "放送局が見つかりません",
            message: "この地域では利用可能な放送局がありません。",
            actionTitle: "地域を変更",
            action: { print("Change area") }
        )
        .frame(height: 200)
        
        Divider()
        
        ErrorView(
            message: "ネットワークに接続できませんでした。",
            retryAction: { print("Retry") }
        )
        .frame(height: 200)
    }
    .background(Color.appBackground)
}