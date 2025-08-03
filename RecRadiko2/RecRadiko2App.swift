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
        // AppLogger初期化テスト
        let logger = AppLogger.shared.category("AppStartup")
        logger.info("RecRadiko2アプリ起動開始")
        logger.debug("AppLogger初期化テスト")
        print("🚀 RecRadiko2App初期化完了")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
