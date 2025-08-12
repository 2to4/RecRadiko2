//
//  RecRadiko2App.swift
//  RecRadiko2
//
//  Created by 吉田太 on 2025/07/24.
//

import SwiftUI

@main
struct RecRadiko2App: App {
    
    init() {
        print("🚀 RecRadiko2App init() 開始")
        
        // AppLogger強制初期化とテスト
        print("🔧 AppLogger強制初期化開始")
        self.initializeAppLogger()
        print("🔧 AppLogger強制初期化完了")
        
        print("🚀 RecRadiko2App初期化完了")
    }
    
    /// AppLoggerを強制的に初期化
    private func initializeAppLogger() {
        print("📝 AppLogger.shared アクセス開始")
        let logger = AppLogger.shared
        print("📝 AppLogger.shared アクセス完了")
        
        print("📝 AppLogger ログ出力テスト開始")
        let categoryLogger = logger.category("AppStartup")
        categoryLogger.info("RecRadiko2アプリ起動開始")
        categoryLogger.debug("AppLogger初期化テスト完了")
        print("📝 AppLogger ログ出力テスト完了")
        
        // ログファイルパスを確認
        if let logPath = logger.currentLogFilePath {
            print("📂 ログファイルパス: \(logPath)")
        } else {
            print("❌ ログファイルパスが取得できません")
        }
        
        print("📂 ログディレクトリパス: \(logger.logDirectoryPath)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, idealWidth: 1200, maxWidth: .infinity,
                       minHeight: 600, idealHeight: 800, maxHeight: .infinity)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            // ファイルメニューのカスタマイズ
            CommandGroup(replacing: .newItem) {
                Button("新規録音") {
                    NotificationCenter.default.post(name: .newRecording, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            // 表示メニューの追加
            CommandMenu("表示") {
                Button("放送局一覧") {
                    NotificationCenter.default.post(name: .showStationList, object: nil)
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("番組表") {
                    NotificationCenter.default.post(name: .showProgramSchedule, object: nil)
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Button("設定") {
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
                
                Divider()
                
                Button("フルスクリーン") {
                    NSApplication.shared.keyWindow?.toggleFullScreen(nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
            }
            
            // ウィンドウメニューのカスタマイズ
            CommandGroup(after: .windowSize) {
                Button("ウィンドウを中央に配置") {
                    if let window = NSApplication.shared.keyWindow {
                        window.center()
                    }
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
            }
        }
    }
}
