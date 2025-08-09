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
        }
    }
}
