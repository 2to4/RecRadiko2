//
//  KeyboardShortcutManager.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/26.
//

import SwiftUI
import Carbon.HIToolbox

/// キーボードショートカットアクション
enum ShortcutAction: String, CaseIterable, Codable {
    case startRecording = "startRecording"
    case stopRecording = "stopRecording"
    case searchProgram = "searchProgram"
    case openSettings = "openSettings"
    case refreshStations = "refreshStations"
    case previousStation = "previousStation"
    case nextStation = "nextStation"
    case cancelOperation = "cancelOperation"
    case showHelp = "showHelp"
    case toggleFullscreen = "toggleFullscreen"
    
    var localizedTitle: String {
        switch self {
        case .startRecording:
            return "録音開始"
        case .stopRecording:
            return "録音停止"
        case .searchProgram:
            return "番組検索"
        case .openSettings:
            return "設定を開く"
        case .refreshStations:
            return "放送局リストを更新"
        case .previousStation:
            return "前の放送局"
        case .nextStation:
            return "次の放送局"
        case .cancelOperation:
            return "操作をキャンセル"
        case .showHelp:
            return "ヘルプを表示"
        case .toggleFullscreen:
            return "フルスクリーン切り替え"
        }
    }
    
    var defaultKeyEquivalent: KeyEquivalent {
        switch self {
        case .startRecording:
            return KeyEquivalent("r")
        case .stopRecording:
            return KeyEquivalent("s")
        case .searchProgram:
            return KeyEquivalent("f")
        case .openSettings:
            return KeyEquivalent(",")
        case .refreshStations:
            return KeyEquivalent("r")
        case .previousStation:
            return KeyEquivalent("[")
        case .nextStation:
            return KeyEquivalent("]")
        case .cancelOperation:
            return KeyEquivalent(".")
        case .showHelp:
            return KeyEquivalent("?")
        case .toggleFullscreen:
            return KeyEquivalent("f")
        }
    }
    
    var defaultModifiers: SwiftUI.EventModifiers {
        switch self {
        case .startRecording, .stopRecording:
            return [.command]
        case .searchProgram:
            return [.command]
        case .openSettings:
            return [.command]
        case .refreshStations:
            return [.command, .shift]
        case .previousStation, .nextStation:
            return [.command]
        case .cancelOperation:
            return [.command]
        case .showHelp:
            return [.command]
        case .toggleFullscreen:
            return [.command, .control]
        }
    }
}

/// キーボードショートカット設定
struct KeyboardShortcut: Codable, Identifiable {
    let id = UUID()
    let action: ShortcutAction
    var keyEquivalent: String
    var modifiers: [String]
    var isEnabled: Bool = true
    
    init(action: ShortcutAction, keyEquivalent: String? = nil, modifiers: [String]? = nil) {
        self.action = action
        self.keyEquivalent = keyEquivalent ?? String(action.defaultKeyEquivalent.character)
        self.modifiers = modifiers ?? action.defaultModifiers.stringArray
    }
    
    var displayString: String {
        let modifierSymbols = modifiers.compactMap { modifier in
            switch modifier {
            case "command": return "⌘"
            case "option": return "⌥"
            case "control": return "⌃"
            case "shift": return "⇧"
            default: return nil
            }
        }
        
        return modifierSymbols.joined() + keyEquivalent.uppercased()
    }
}

/// キーボードショートカットマネージャー
@MainActor
class KeyboardShortcutManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var shortcuts: [KeyboardShortcut] = []
    @Published var isRecordingShortcut = false
    @Published var pendingShortcut: KeyboardShortcut?
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let shortcutsKey = "RecRadiko2.KeyboardShortcuts"
    
    // MARK: - Action Handlers
    
    var onStartRecording: (() -> Void)?
    var onStopRecording: (() -> Void)?
    var onSearchProgram: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onRefreshStations: (() -> Void)?
    var onPreviousStation: (() -> Void)?
    var onNextStation: (() -> Void)?
    var onCancelOperation: (() -> Void)?
    var onShowHelp: (() -> Void)?
    var onToggleFullscreen: (() -> Void)?
    
    // MARK: - Initialization
    
    init() {
        loadShortcuts()
    }
    
    // MARK: - Shortcuts Management
    
    /// ショートカット設定のロード
    private func loadShortcuts() {
        if let data = userDefaults.data(forKey: shortcutsKey),
           let loadedShortcuts = try? JSONDecoder().decode([KeyboardShortcut].self, from: data) {
            shortcuts = loadedShortcuts
        } else {
            // デフォルトショートカットを作成
            shortcuts = ShortcutAction.allCases.map { action in
                KeyboardShortcut(action: action)
            }
            saveShortcuts()
        }
    }
    
    /// ショートカット設定の保存
    private func saveShortcuts() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            userDefaults.set(data, forKey: shortcutsKey)
        }
    }
    
    /// ショートカットの更新
    func updateShortcut(_ shortcut: KeyboardShortcut) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index] = shortcut
            saveShortcuts()
        }
    }
    
    /// ショートカットの有効/無効切り替え
    func toggleShortcut(_ shortcut: KeyboardShortcut) {
        var updatedShortcut = shortcut
        updatedShortcut.isEnabled.toggle()
        updateShortcut(updatedShortcut)
    }
    
    /// デフォルト設定に戻す
    func resetToDefaults() {
        shortcuts = ShortcutAction.allCases.map { action in
            KeyboardShortcut(action: action)
        }
        saveShortcuts()
    }
    
    // MARK: - Shortcut Recording
    
    /// ショートカット記録開始
    func startRecordingShortcut(for shortcut: KeyboardShortcut) {
        isRecordingShortcut = true
        pendingShortcut = shortcut
    }
    
    /// ショートカット記録停止
    func stopRecordingShortcut() {
        isRecordingShortcut = false
        pendingShortcut = nil
    }
    
    /// 新しいショートカットを記録
    func recordShortcut(keyEquivalent: String, modifiers: [String]) {
        guard var shortcut = pendingShortcut else { return }
        
        shortcut.keyEquivalent = keyEquivalent
        shortcut.modifiers = modifiers
        
        updateShortcut(shortcut)
        stopRecordingShortcut()
    }
    
    // MARK: - Action Execution
    
    /// ショートカットアクションの実行
    func executeAction(_ action: ShortcutAction) {
        // ショートカットが有効かチェック
        guard let shortcut = shortcuts.first(where: { $0.action == action }),
              shortcut.isEnabled else {
            return
        }
        
        switch action {
        case .startRecording:
            onStartRecording?()
        case .stopRecording:
            onStopRecording?()
        case .searchProgram:
            onSearchProgram?()
        case .openSettings:
            onOpenSettings?()
        case .refreshStations:
            onRefreshStations?()
        case .previousStation:
            onPreviousStation?()
        case .nextStation:
            onNextStation?()
        case .cancelOperation:
            onCancelOperation?()
        case .showHelp:
            onShowHelp?()
        case .toggleFullscreen:
            onToggleFullscreen?()
        }
    }
    
    // MARK: - Shortcut Validation
    
    /// ショートカットの重複チェック
    func isDuplicateShortcut(keyEquivalent: String, modifiers: [String], excluding: UUID? = nil) -> Bool {
        return shortcuts.contains { shortcut in
            shortcut.id != excluding &&
            shortcut.keyEquivalent == keyEquivalent &&
            shortcut.modifiers == modifiers &&
            shortcut.isEnabled
        }
    }
    
    /// ショートカットの有効性チェック
    func isValidShortcut(keyEquivalent: String, modifiers: [String]) -> Bool {
        // 最低限のバリデーション
        guard !keyEquivalent.isEmpty else { return false }
        
        // システム予約ショートカットのチェック
        let systemShortcuts = [
            ("q", ["command"]), // Quit
            ("w", ["command"]), // Close Window
            ("n", ["command"]), // New
            ("o", ["command"]), // Open
            ("s", ["command"]), // Save
            ("z", ["command"]), // Undo
            ("c", ["command"]), // Copy
            ("v", ["command"]), // Paste
            ("x", ["command"])  // Cut
        ]
        
        let isSystemShortcut = systemShortcuts.contains { shortcut in
            shortcut.0 == keyEquivalent.lowercased() && shortcut.1 == modifiers
        }
        
        return !isSystemShortcut
    }
}

// MARK: - EventModifiers Extensions

extension SwiftUI.EventModifiers {
    var stringArray: [String] {
        var result: [String] = []
        
        if contains(.command) { result.append("command") }
        if contains(.option) { result.append("option") }
        if contains(.control) { result.append("control") }
        if contains(.shift) { result.append("shift") }
        
        return result
    }
    
    init(stringArray: [String]) {
        self = []
        
        for modifier in stringArray {
            switch modifier {
            case "command":
                insert(.command)
            case "option":
                insert(.option)
            case "control":
                insert(.control)
            case "shift":
                insert(.shift)
            default:
                break
            }
        }
    }
}

// MARK: - Keyboard Shortcut View Components

struct KeyboardShortcutRecorderView: View {
    @ObservedObject var shortcutManager: KeyboardShortcutManager
    let shortcut: KeyboardShortcut
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(shortcut.action.localizedTitle)
                    .font(.body)
                
                Text(shortcut.displayString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(shortcutManager.isRecordingShortcut && shortcutManager.pendingShortcut?.id == shortcut.id ? "記録中..." : "変更") {
                if shortcutManager.isRecordingShortcut {
                    shortcutManager.stopRecordingShortcut()
                } else {
                    shortcutManager.startRecordingShortcut(for: shortcut)
                }
            }
            .disabled(!shortcut.isEnabled)
            
            Toggle("", isOn: Binding(
                get: { shortcut.isEnabled },
                set: { _ in shortcutManager.toggleShortcut(shortcut) }
            ))
        }
        .padding(.vertical, 4)
    }
}

struct KeyboardShortcutSettingsView: View {
    @ObservedObject var shortcutManager: KeyboardShortcutManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("キーボードショートカット")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("アプリケーションの操作にキーボードショートカットを使用できます。")
                .font(.body)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(shortcutManager.shortcuts) { shortcut in
                        KeyboardShortcutRecorderView(
                            shortcutManager: shortcutManager,
                            shortcut: shortcut
                        )
                        
                        if shortcut.id != shortcutManager.shortcuts.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.vertical)
            }
            
            HStack {
                Button("デフォルトに戻す") {
                    shortcutManager.resetToDefaults()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if shortcutManager.isRecordingShortcut {
                    Button("キャンセル") {
                        shortcutManager.stopRecordingShortcut()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(maxWidth: 500)
    }
}

// MARK: - Key Event Handling

extension KeyboardShortcutManager {
    /// キーイベントの処理
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        
        let keyEquivalent = event.charactersIgnoringModifiers ?? ""
        let modifiers = event.modifierFlags.stringArray
        
        // ショートカット記録中の場合
        if isRecordingShortcut {
            recordShortcut(keyEquivalent: keyEquivalent, modifiers: modifiers)
            return true
        }
        
        // 登録されたショートカットをチェック
        for shortcut in shortcuts where shortcut.isEnabled {
            if shortcut.keyEquivalent.lowercased() == keyEquivalent.lowercased() &&
               shortcut.modifiers == modifiers {
                executeAction(shortcut.action)
                return true
            }
        }
        
        return false
    }
}

extension NSEvent.ModifierFlags {
    var stringArray: [String] {
        var result: [String] = []
        
        if contains(.command) { result.append("command") }
        if contains(.option) { result.append("option") }
        if contains(.control) { result.append("control") }
        if contains(.shift) { result.append("shift") }
        
        return result
    }
}