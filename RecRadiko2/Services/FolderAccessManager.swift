//
//  FolderAccessManager.swift
//  RecRadiko2
//
//  Created by Claude on 2025/08/12.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

/// macOSサンドボックス対応のフォルダアクセス管理
@MainActor
class FolderAccessManager: ObservableObject {
    
    private let userDefaults = UserDefaults.standard
    private let bookmarkKey = "selectedFolderBookmark"
    
    /// 保存されたフォルダブックマークからURLを復元
    /// - Returns: アクセス可能なフォルダURL、または nil
    func restoreBookmarkedFolder() -> URL? {
        guard let bookmarkData = userDefaults.data(forKey: bookmarkKey) else {
            print("❌ [FolderAccessManager] ブックマークが保存されていません")
            return nil
        }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, 
                             options: [.withSecurityScope],
                             relativeTo: nil,
                             bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("⚠️ [FolderAccessManager] ブックマークが古くなっています")
                // 古いブックマークを削除
                userDefaults.removeObject(forKey: bookmarkKey)
                return nil
            }
            
            // セキュリティスコープアクセス開始
            let accessed = url.startAccessingSecurityScopedResource()
            print("✅ [FolderAccessManager] フォルダアクセス復元: \(url.path), accessed: \(accessed)")
            
            return url
        } catch {
            print("❌ [FolderAccessManager] ブックマーク復元失敗: \(error)")
            userDefaults.removeObject(forKey: bookmarkKey)
            return nil
        }
    }
    
    /// フォルダ選択ダイアログを表示してブックマークを保存
    /// - Returns: 選択されたフォルダURL、またはnil
    func selectAndBookmarkFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "録音ファイルの保存先フォルダを選択してください"
        panel.message = "RecRadiko2が録音ファイルを保存するフォルダを選択してください。\n選択したフォルダへの継続的なアクセスが許可されます。"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        
        // デフォルトでDownloadsフォルダを表示
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        
        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            print("❌ [FolderAccessManager] フォルダ選択がキャンセルされました")
            return nil
        }
        
        print("📁 [FolderAccessManager] フォルダ選択: \(selectedURL.path)")
        
        // ブックマーク作成と保存
        do {
            let bookmarkData = try selectedURL.bookmarkData(options: [.withSecurityScope],
                                                          includingResourceValuesForKeys: nil,
                                                          relativeTo: nil)
            userDefaults.set(bookmarkData, forKey: bookmarkKey)
            print("✅ [FolderAccessManager] ブックマーク保存完了")
            
            return selectedURL
        } catch {
            print("❌ [FolderAccessManager] ブックマーク保存失敗: \(error)")
            return nil
        }
    }
    
    /// セキュリティスコープアクセスを終了
    /// - Parameter url: アクセスを終了するURL
    func stopAccessingFolder(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
        print("🔒 [FolderAccessManager] セキュリティスコープアクセス終了: \(url.path)")
    }
    
    /// 保存されたブックマークをクリア
    func clearBookmark() {
        userDefaults.removeObject(forKey: bookmarkKey)
        print("🗑️ [FolderAccessManager] ブックマーククリア完了")
    }
    
    /// 利用可能なフォルダ（Downloadsまたはブックマーク済み）を取得
    /// - Returns: アクセス可能なフォルダURL
    func getAvailableFolder() -> URL? {
        // 1. まずブックマーク済みフォルダを試行
        if let bookmarkedFolder = restoreBookmarkedFolder() {
            return bookmarkedFolder
        }
        
        // 2. Downloadsフォルダを使用（サンドボックス許可済み）
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        print("📥 [FolderAccessManager] Downloadsフォルダを使用: \(downloadsURL?.path ?? "nil")")
        return downloadsURL
    }
    
    /// フォルダ選択が必要かどうかを判定
    /// - Returns: フォルダ選択が必要な場合true
    func needsFolderSelection() -> Bool {
        return userDefaults.data(forKey: bookmarkKey) == nil
    }
}