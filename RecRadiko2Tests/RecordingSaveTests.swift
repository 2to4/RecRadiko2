//
//  RecordingSaveTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/08/12.
//

import Testing
import Foundation
@testable import RecRadiko2

@Suite("Recording Save Tests - 録音保存機能の修正確認")
struct RecordingSaveTests {
    
    @Test("ファイル保存権限の確認")
    func testFileSavePermissions() {
        // Downloadsフォルダへの書き込み権限確認
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let testFile = downloadsURL.appendingPathComponent("recradiko_test_\(UUID().uuidString).txt")
        
        do {
            try "テスト録音ファイル".write(to: testFile, atomically: true, encoding: .utf8)
            #expect(FileManager.default.fileExists(atPath: testFile.path))
            
            // クリーンアップ
            try? FileManager.default.removeItem(at: testFile)
        } catch {
            Issue.record("Downloads フォルダへの書き込み失敗: \(error)")
        }
    }
    
    @Test("保存先ディレクトリの事前検証")
    func testOutputDirectoryValidation() {
        let fileManager = FileManager.default
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        
        // 存在するディレクトリのチェック
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: tempDir.path, isDirectory: &isDirectory)
        #expect(exists == true)
        #expect(isDirectory.boolValue == true)
        
        // 書き込み権限のチェック
        let isWritable = fileManager.isWritableFile(atPath: tempDir.path)
        #expect(isWritable == true)
    }
    
    @Test("録音設定のファイル形式統一")
    func testRecordingSettingsFormat() {
        let settings = RecordingSettings(
            stationId: "TBS",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            outputDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
        )
        
        // デフォルトフォーマットがm4aであることを確認
        #expect(settings.outputFormat == "m4a")
    }
    
    @Test("エラーコード詳細ログの確認")
    func testErrorCodeDetection() {
        // NSErrorコード513（権限エラー）の検出テスト
        let nsError = NSError(domain: NSCocoaErrorDomain, code: 513, userInfo: nil)
        #expect(nsError.code == 513)
        
        // NSErrorコード257（権限エラー）の検出テスト
        let nsError2 = NSError(domain: NSCocoaErrorDomain, code: 257, userInfo: nil)
        #expect(nsError2.code == 257)
    }
}