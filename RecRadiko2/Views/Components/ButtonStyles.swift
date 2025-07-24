//
//  ButtonStyles.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import SwiftUI

/// プライマリボタンスタイル
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.appPrimaryText)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.appAccent)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// セカンダリボタンスタイル（設定画面用）
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 5)
            .background(Color.gray.opacity(0.8))
            .cornerRadius(5)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 危険操作ボタンスタイル（キャンセル等）
struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.appPrimaryText)
            .padding(.horizontal, 30)
            .padding(.vertical, 10)
            .background(Color.appDanger)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 成功ボタンスタイル
struct SuccessButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.appPrimaryText)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.appSuccess)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// テキストボタンスタイル（背景なし）
struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.appAccent)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// ナビゲーションボタンスタイル（戻るボタン等）
struct NavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.appPrimaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.appUIBackground)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}