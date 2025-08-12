//
//  SettingsViewModel.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import Foundation
import SwiftUI

/// 設定画面のViewModel
@MainActor
final class SettingsViewModel: BaseViewModel {
    // MARK: - AppStorage Properties
    /// 保存先ディレクトリパス
    @AppStorage("saveDirectoryPath") var saveDirectoryPath: String = "~/Downloads" {
        didSet {
            validateSaveDirectory()
        }
    }
    
    /// ラジコプレミアムメールアドレス
    @AppStorage("premiumEmail") var premiumEmail: String = ""
    
    /// ラジコプレミアムパスワード
    @AppStorage("premiumPassword") var premiumPassword: String = ""
    
    /// 初回起動フラグ
    @AppStorage("isFirstLaunch") var isFirstLaunch: Bool = true
    
    /// 選択中の地域ID
    @AppStorage("selectedAreaId") var selectedAreaId: String = "JP13"
    
    // MARK: - Published Properties
    /// ディレクトリ選択ダイアログ表示フラグ
    @Published var showingDirectoryPicker = false
    
    /// 保存先ディレクトリの有効性確認結果
    @Published var isDirectoryValid = true
    
    /// プレミアム認証テスト中フラグ
    @Published var isTestingPremiumConnection = false
    
    // MARK: - Computed Properties
    /// 保存先ディレクトリの表示用パス
    var displayDirectoryPath: String {
        saveDirectoryPath.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
    }
    
    /// プレミアム認証情報が有効かどうか
    var isPremiumCredentialsValid: Bool {
        !premiumEmail.isEmpty && !premiumPassword.isEmpty
    }
    
    // MARK: - 初期化
    override init() {
        super.init()
        setupInitialValues()
        validateSaveDirectory()
    }
    
    // MARK: - セットアップ
    /// 初期値設定
    private func setupInitialValues() {
        if isFirstLaunch {
            // 初回起動時のデフォルト設定
            saveDirectoryPath = "~/Downloads"
            selectedAreaId = "JP13" // 東京
            isFirstLaunch = false
        }
    }
    
    // MARK: - Public Methods
    /// 保存先ディレクトリ選択ダイアログを表示
    func selectSaveDirectory() {
        showingDirectoryPicker = true
    }
    
    /// 保存先ディレクトリを更新
    /// - Parameter url: 選択されたディレクトリURL
    func updateSaveDirectory(_ url: URL) {
        saveDirectoryPath = url.path
        showingDirectoryPicker = false
    }
    
    /// 保存先ディレクトリの有効性確認
    private func validateSaveDirectory() {
        let expandedPath = displayDirectoryPath
        let fileManager = FileManager.default
        
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory)
        
        isDirectoryValid = exists && isDirectory.boolValue
        
        if !isDirectoryValid {
            showError("保存先ディレクトリが存在しないか、アクセスできません: \(expandedPath)")
        } else {
            clearError()
        }
    }
    
    /// プレミアム認証情報の検証
    /// - Returns: 認証情報が有効かどうか
    func validatePremiumCredentials() -> Bool {
        let isValid = !premiumEmail.isEmpty && 
                     !premiumPassword.isEmpty && 
                     premiumEmail.contains("@")
        
        if !isValid {
            showError("有効なメールアドレスとパスワードを入力してください")
        } else {
            clearError()
        }
        
        return isValid
    }
    
    /// プレミアム認証接続テスト
    func testPremiumConnection() {
        guard validatePremiumCredentials() else { return }
        
        isTestingPremiumConnection = true
        clearError()
        
        // Phase 1: モック実装（将来実装予定メッセージ）
        Task {
            // 接続テストのシミュレーション
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒待機
            
            await MainActor.run {
                isTestingPremiumConnection = false
                // Phase 1では将来実装予定のメッセージを表示
                showError("プレミアム認証機能は将来実装予定です")
            }
        }
    }
    
    /// 設定をリセット
    func resetSettings() {
        saveDirectoryPath = "~/Downloads"
        premiumEmail = ""
        premiumPassword = ""
        selectedAreaId = "JP13"
        
        clearError()
        validateSaveDirectory()
    }
    
    /// URL指定でディレクトリを更新
    /// - Parameter url: 選択されたディレクトリURL
    func updateSaveDirectoryFromURL(_ url: URL) {
        saveDirectoryPath = url.path
        validateSaveDirectory()
    }
    
    /// Downloadsフォルダにリセット
    func resetToDownloadsFolder() {
        saveDirectoryPath = "~/Downloads"
        validateSaveDirectory()
    }
    
    /// ディスク容量確認
    /// - Returns: 利用可能な容量（バイト）
    func getAvailableDiskSpace() -> Int64 {
        let expandedPath = displayDirectoryPath
        
        do {
            let fileURL = URL(fileURLWithPath: expandedPath)
            let resourceValues = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return Int64(resourceValues.volumeAvailableCapacity ?? 0)
        } catch {
            return 0
        }
    }
    
    /// 容量不足チェック（6時間分の録音容量）
    /// - Returns: 容量が十分かどうか
    func hasEnoughSpaceForRecording() -> Bool {
        let requiredBytes: Int64 = 864 * 1024 * 1024 // 864MB（320kbps × 6時間）
        let availableBytes = getAvailableDiskSpace()
        return availableBytes >= requiredBytes
    }
    
    /// 利用可能容量の表示用文字列
    var availableSpaceString: String {
        let bytes = getAvailableDiskSpace()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}