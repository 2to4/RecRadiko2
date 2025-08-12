//
//  RecordingProgressTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/08/11.
//

import Testing
import Foundation
@testable import RecRadiko2

@Suite("Recording Progress Tests - 録音進捗修正のテスト")
struct RecordingProgressTests {
    
    @Test("ProgressCounterの動作確認")
    @MainActor
    func testProgressCounter() async {
        let counter = ProgressCounter()
        
        // 初期状態は0
        let first = counter.increment()
        #expect(first == 1)
        
        let second = counter.increment()
        #expect(second == 2)
        
        let third = counter.increment()
        #expect(third == 3)
        
        // リセットして再確認
        counter.reset()
        let afterReset = counter.increment()
        #expect(afterReset == 1)
    }
    
    @Test("RecordingProgressの進捗計算確認")
    func testRecordingProgressCalculation() {
        let progress = RecordingProgress(
            state: .downloading,
            downloadedSegments: 25,
            totalSegments: 100,
            downloadedBytes: 5000000,
            estimatedTotalBytes: 20000000,
            currentProgram: nil
        )
        
        // 25%の進捗であることを確認
        #expect(progress.progressPercentage == 0.25)
        #expect(progress.isCompleted == false)
        #expect(progress.isFailed == false)
    }
    
    @Test("完了状態の進捗確認")
    func testCompletedProgress() {
        let progress = RecordingProgress(
            state: .completed,
            downloadedSegments: 100,
            totalSegments: 100,
            downloadedBytes: 20000000,
            estimatedTotalBytes: 20000000,
            currentProgram: nil
        )
        
        // 100%完了
        #expect(progress.progressPercentage == 1.0)
        #expect(progress.isCompleted == true)
        #expect(progress.isFailed == false)
    }
    
    @Test("エラー状態の進捗確認")
    func testFailedProgress() {
        let error = RecordingError.networkError(NSError(domain: "test", code: 404, userInfo: nil))
        let progress = RecordingProgress(
            state: .failed(error),
            downloadedSegments: 10,
            totalSegments: 100,
            downloadedBytes: 2000000,
            estimatedTotalBytes: 20000000,
            currentProgram: nil
        )
        
        // 10%の進捗だが失敗状態
        #expect(progress.progressPercentage == 0.1)
        #expect(progress.isCompleted == false)
        #expect(progress.isFailed == true)
    }
}