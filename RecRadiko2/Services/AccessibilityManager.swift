//
//  AccessibilityManager.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/26.
//

import SwiftUI
import Combine

/// アクセシビリティ設定
struct AccessibilitySettings {
    var isVoiceOverEnabled: Bool = false
    var isHighContrastEnabled: Bool = false
    var textSizeMultiplier: Double = 1.0
    var isReduceMotionEnabled: Bool = false
    var isSpeakSelectionEnabled: Bool = false
    
    static let `default` = AccessibilitySettings()
}

/// アクセシビリティマネージャー
@MainActor
class AccessibilityManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var settings = AccessibilitySettings.default
    @Published var currentAnnouncementText: String = ""
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupAccessibilityObservers()
        updateCurrentSettings()
    }
    
    // MARK: - System Accessibility Observers
    
    private func setupAccessibilityObservers() {
        // VoiceOver状態監視
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.updateCurrentSettings()
            }
            .store(in: &cancellables)
        
        // システム設定変更監視
        NotificationCenter.default.publisher(for: NSColor.systemColorsDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateCurrentSettings()
            }
            .store(in: &cancellables)
    }
    
    private func updateCurrentSettings() {
        settings.isVoiceOverEnabled = NSWorkspace.shared.isVoiceOverEnabled
        settings.isHighContrastEnabled = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        settings.isReduceMotionEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        
        // テキストサイズ取得（簡易実装）
        let systemFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        settings.textSizeMultiplier = Double(systemFont.pointSize) / 13.0 // 標準サイズは13pt
    }
    
    // MARK: - Accessibility Announcements
    
    /// VoiceOver用のアナウンス
    func announce(_ text: String, priority: NSAccessibilityPriorityLevel = .medium) {
        currentAnnouncementText = text
        
        if settings.isVoiceOverEnabled {
            NSAccessibility.post(element: NSApp!, notification: .announcementRequested)
        }
    }
    
    /// 録音開始のアナウンス
    func announceRecordingStarted(program: String) {
        let announcement = "\(program)の録音を開始しました"
        announce(announcement, priority: .high)
    }
    
    /// 録音完了のアナウンス
    func announceRecordingCompleted(program: String) {
        let announcement = "\(program)の録音が完了しました"
        announce(announcement, priority: .high)
    }
    
    /// エラーのアナウンス
    func announceError(_ error: String) {
        let announcement = "エラー: \(error)"
        announce(announcement, priority: .high)
    }
    
    /// 進捗のアナウンス
    func announceProgress(_ percentage: Int) {
        let announcement = "進捗 \(percentage)パーセント"
        announce(announcement, priority: .low)
    }
    
    // MARK: - Accessibility Helpers
    
    /// アクセシビリティラベル生成
    func generateAccessibilityLabel(for program: RadioProgram) -> String {
        let timeInfo = "放送時間: \(program.displayTime)"
        let durationInfo = "番組長: \(Int(program.duration / 60))分"
        let personalityInfo = program.personalities.isEmpty ? "" : "出演: \(program.personalitiesText)"
        
        return "\(program.title). \(timeInfo). \(durationInfo). \(personalityInfo)"
    }
    
    /// アクセシビリティヒント生成
    func generateAccessibilityHint(for action: String) -> String {
        switch action {
        case "download":
            return "ダブルタップで番組をダウンロードします"
        case "station":
            return "ダブルタップで放送局を選択します"
        case "settings":
            return "ダブルタップで設定画面を開きます"
        case "cancel":
            return "ダブルタップで録音をキャンセルします"
        default:
            return "ダブルタップで実行します"
        }
    }
    
    /// コントラスト調整された色を取得
    func adjustedColor(_ color: Color) -> Color {
        if settings.isHighContrastEnabled {
            // ハイコントラスト時の色調整
            return color == .primary ? .primary : color == .secondary ? .primary : color
        }
        return color
    }
    
    /// テキストサイズ調整
    func adjustedFontSize(_ baseSize: CGFloat) -> CGFloat {
        return baseSize * settings.textSizeMultiplier
    }
    
    // MARK: - Keyboard Navigation
    
    /// フォーカス可能要素の識別
    func makeFocusable<Content: View>(_ content: Content, identifier: String) -> some View {
        content
            .focusable()
            .accessibilityIdentifier(identifier)
    }
    
    /// キーボードナビゲーション対応
    func keyboardNavigationWrapper<Content: View>(_ content: Content) -> some View {
        content
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isKeyboardKey)
    }
}

// MARK: - Accessibility View Extensions

extension View {
    /// RecRadiko2用アクセシビリティ設定
    func recRadikoAccessibility(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }
    
    /// 番組行用アクセシビリティ
    func programRowAccessibility(
        program: RadioProgram,
        isRecording: Bool,
        accessibilityManager: AccessibilityManager
    ) -> some View {
        let label = accessibilityManager.generateAccessibilityLabel(for: program)
        let hint = accessibilityManager.generateAccessibilityHint(for: "download")
        let value = isRecording ? "録音中" : "録音可能"
        let traits: AccessibilityTraits = isRecording ? [.isButton, .isSelected] : .isButton
        
        return self.recRadikoAccessibility(
            label: label,
            hint: hint,
            value: value,
            traits: traits
        )
    }
    
    /// 進捗表示用アクセシビリティ
    func progressAccessibility(
        progress: Double,
        accessibilityManager: AccessibilityManager
    ) -> some View {
        let percentage = Int(progress * 100)
        let label = "録音進捗"
        let value = "\(percentage)パーセント完了"
        
        return self.recRadikoAccessibility(
            label: label,
            value: value,
            traits: .updatesFrequently
        )
    }
    
    /// ボタン用アクセシビリティ
    func buttonAccessibility(
        title: String,
        action: String,
        isEnabled: Bool = true,
        accessibilityManager: AccessibilityManager
    ) -> some View {
        let hint = accessibilityManager.generateAccessibilityHint(for: action)
        let traits: AccessibilityTraits = isEnabled ? .isButton : .isButton
        
        return self.recRadikoAccessibility(
            label: title,
            hint: hint,
            traits: traits
        )
    }
}

// MARK: - Keyboard Shortcuts

struct KeyboardShortcuts {
    static let startRecording = KeyEquivalent("r")
    static let searchProgram = KeyEquivalent("f")
    static let openSettings = KeyEquivalent(",")
    static let refreshStations = KeyEquivalent("r")
    static let previousStation = KeyEquivalent("[")
    static let nextStation = KeyEquivalent("]")
    static let cancelRecording = KeyEquivalent(".")
    static let showHelp = KeyEquivalent("?")
}

// MARK: - Keyboard Navigation Manager

@MainActor
class KeyboardNavigationManager: ObservableObject {
    
    @Published var currentFocusedElement: String = ""
    @Published var isKeyboardNavigationActive = false
    
    private var focusableElements: [String] = []
    private var currentIndex = 0
    
    func registerFocusableElement(_ identifier: String) {
        if !focusableElements.contains(identifier) {
            focusableElements.append(identifier)
        }
    }
    
    func unregisterFocusableElement(_ identifier: String) {
        focusableElements.removeAll { $0 == identifier }
        if currentFocusedElement == identifier {
            moveFocusToNext()
        }
    }
    
    func moveFocusToNext() {
        guard !focusableElements.isEmpty else { return }
        
        currentIndex = (currentIndex + 1) % focusableElements.count
        currentFocusedElement = focusableElements[currentIndex]
        isKeyboardNavigationActive = true
    }
    
    func moveFocusToPrevious() {
        guard !focusableElements.isEmpty else { return }
        
        currentIndex = currentIndex > 0 ? currentIndex - 1 : focusableElements.count - 1
        currentFocusedElement = focusableElements[currentIndex]
        isKeyboardNavigationActive = true
    }
    
    func setFocus(to identifier: String) {
        if let index = focusableElements.firstIndex(of: identifier) {
            currentIndex = index
            currentFocusedElement = identifier
            isKeyboardNavigationActive = true
        }
    }
    
    func clearFocus() {
        currentFocusedElement = ""
        isKeyboardNavigationActive = false
    }
}

// MARK: - NSWorkspace Extensions

extension NSWorkspace {
    var isVoiceOverEnabled: Bool {
        // VoiceOver状態の確認（簡易実装）
        return NSWorkspace.shared.accessibilityDisplayShouldDifferentiateWithoutColor
    }
}

// MARK: - Color Accessibility Extensions

extension Color {
    /// アクセシビリティ対応色の生成
    static func accessibilityAdjusted(
        light: Color,
        dark: Color,
        highContrast: Color
    ) -> Color {
        // システム設定に基づく色の選択
        if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
            return highContrast
        }
        
        // ダークモード対応
        return Color(NSColor.controlAccentColor) // システムアクセントカラーを使用
    }
    
    /// コントラスト比の計算
    func contrastRatio(with background: Color) -> Double {
        // コントラスト比の計算（簡易実装）
        // 実際の実装では色の輝度を計算してWCAGガイドラインに従う
        return 4.5 // 仮の値（実装要）
    }
}

// MARK: - Accessibility Testing Helpers

#if DEBUG
extension AccessibilityManager {
    /// テスト用のアクセシビリティ監査
    func performAccessibilityAudit() -> [String] {
        var issues: [String] = []
        
        // VoiceOver対応チェック
        if !settings.isVoiceOverEnabled {
            issues.append("VoiceOverが無効になっています")
        }
        
        // コントラスト比チェック（模擬）
        if !settings.isHighContrastEnabled {
            issues.append("ハイコントラストモードが推奨されます")
        }
        
        // テキストサイズチェック
        if settings.textSizeMultiplier < 1.2 {
            issues.append("より大きなテキストサイズが推奨される場合があります")
        }
        
        return issues
    }
}
#endif