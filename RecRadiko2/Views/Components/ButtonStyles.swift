//
//  ButtonStyles.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//  Updated for HIG compliance on 2025/08/11.
//

import SwiftUI

// MARK: - Primary Button Style (主要アクション)
/// macOSネイティブの主要アクションボタンスタイル
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButtonText)
            .foregroundColor(isEnabled ? .white : .appDisabledText)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(buttonBackground(isPressed: configuration.isPressed))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.appBorder.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
    }
    
    private func buttonBackground(isPressed: Bool) -> Color {
        if !isEnabled {
            return Color.appDisabledBackground
        } else if isPressed {
            return Color.accentColor.opacity(0.8)
        } else if isHovered {
            return Color.accentColor.opacity(0.9)
        } else {
            return Color.accentColor
        }
    }
}

// MARK: - Secondary Button Style (副次アクション)
/// macOSネイティブの副次アクションボタンスタイル
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButtonText)
            .foregroundColor(isEnabled ? .appPrimaryText : .appDisabledText)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(buttonBackground(isPressed: configuration.isPressed))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.appBorder, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
    }
    
    private func buttonBackground(isPressed: Bool) -> Color {
        if !isEnabled {
            return Color.appDisabledBackground
        } else if isPressed {
            return Color.appPressedBackground
        } else if isHovered {
            return Color.appHoverBackground
        } else {
            return Color.appUIBackground
        }
    }
}

// MARK: - Destructive Button Style (破壊的アクション)
/// 削除・キャンセル等の破壊的操作用ボタンスタイル
struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButtonText)
            .foregroundColor(isEnabled ? .white : .appDisabledText)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(buttonBackground(isPressed: configuration.isPressed))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.appDanger.opacity(0.3), lineWidth: 0.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
    }
    
    private func buttonBackground(isPressed: Bool) -> Color {
        if !isEnabled {
            return Color.appDisabledBackground
        } else if isPressed {
            return Color.appDanger.opacity(0.8)
        } else if isHovered {
            return Color.appDanger.opacity(0.9)
        } else {
            return Color.appDanger
        }
    }
}

// MARK: - Borderless Button Style (ボーダーレス)
/// テキストリンク風のボーダーレスボタンスタイル
struct BorderlessButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButtonText)
            .foregroundColor(buttonColor(isPressed: configuration.isPressed))
            .underline(isHovered, color: Color.accentColor)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
    }
    
    private func buttonColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return Color.appDisabledText
        } else if isPressed {
            return Color.accentColor.opacity(0.7)
        } else if isHovered {
            return Color.accentColor
        } else {
            return Color.accentColor.opacity(0.9)
        }
    }
}

// MARK: - Toolbar Button Style (ツールバー)
/// ツールバー用のコンパクトなボタンスタイル
struct ToolbarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appCaption)
            .foregroundColor(isEnabled ? .appPrimaryText : .appDisabledText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(buttonBackground(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        isHovered ? Color.appBorder : Color.clear,
                        lineWidth: 1
                    )
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
    
    private func buttonBackground(isPressed: Bool) -> Color {
        if !isEnabled {
            return Color.clear
        } else if isPressed {
            return Color.appPressedBackground
        } else if isHovered {
            return Color.appHoverBackground
        } else {
            return Color.clear
        }
    }
}

// MARK: - Card Button Style (カード型)
/// カード型のボタンスタイル（放送局選択等）
struct CardButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(cardBackground(isPressed: configuration.isPressed))
                    .shadow(
                        color: shadowColor(isHovered: isHovered),
                        radius: isHovered ? 8 : 4,
                        x: 0,
                        y: isHovered ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        borderColor(isHovered: isHovered),
                        lineWidth: isHovered ? 2 : 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
    
    private func cardBackground(isPressed: Bool) -> Color {
        if !isEnabled {
            return Color.appDisabledBackground
        } else if isPressed {
            return Color.appSelectedBackground
        } else {
            return Color.appSecondaryBackground
        }
    }
    
    private func shadowColor(isHovered: Bool) -> Color {
        return isHovered ? Color.black.opacity(0.3) : Color.black.opacity(0.2)
    }
    
    private func borderColor(isHovered: Bool) -> Color {
        return isHovered ? Color.accentColor : Color.appBorder.opacity(0.5)
    }
}

// MARK: - Legacy Styles (互換性維持用)
/// 旧バージョンとの互換性維持用
struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DestructiveButtonStyle().makeBody(configuration: configuration)
    }
}

struct SuccessButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonStyle().makeBody(configuration: configuration)
    }
}

struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BorderlessButtonStyle().makeBody(configuration: configuration)
    }
}

struct NavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SecondaryButtonStyle().makeBody(configuration: configuration)
    }
}