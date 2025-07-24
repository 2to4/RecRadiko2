//
//  RecordingViewModel.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import Foundation
import Combine

/// 録音進捗画面のViewModel
@MainActor
final class RecordingViewModel: BaseViewModel {
    // MARK: - Published Properties
    /// 録音中かどうか
    @Published var isRecording: Bool = false
    
    /// 録音進捗（0.0-1.0）
    @Published var recordingProgress: Double = 0.0
    
    /// 経過時間（秒）
    @Published var elapsedTime: TimeInterval = 0
    
    /// 録音中の番組
    @Published var currentProgram: RadioProgram?
    
    /// 推定完了時間
    @Published var estimatedEndTime: Date?
    
    // MARK: - Private Properties
    /// 進捗更新タイマー
    private var progressTimer: Timer?
    
    /// 録音開始時刻
    private var recordingStartTime: Date?
    
    // MARK: - Dependencies（Phase 3で実装予定）
    private let recordingService: RecordingServiceProtocol = MockRecordingService()
    
    // MARK: - Computed Properties
    /// 経過時間の文字列表示（MM:SS形式）
    var elapsedTimeString: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// 残り時間の文字列表示
    var remainingTimeString: String {
        guard let program = currentProgram else { return "--:--" }
        
        let totalDuration = program.duration
        let remainingTime = max(0, totalDuration - elapsedTime)
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// 録音状態の説明文
    var statusText: String {
        if isRecording {
            return "録音中..."
        } else {
            return "待機中"
        }
    }
    
    // MARK: - 初期化
    override init() {
        super.init()
    }
    
    // MARK: - セットアップ
    override func setupNotifications() {
        // 録音開始通知の受信
        NotificationCenter.default.publisher(for: .recordingStarted)
            .compactMap { $0.object as? RadioProgram }
            .sink { [weak self] program in
                Task { @MainActor in
                    await self?.startRecording(program: program)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    /// 録音開始
    /// - Parameter program: 録音する番組
    func startRecording(program: RadioProgram) async {
        guard !isRecording else { return }
        
        currentProgram = program
        recordingStartTime = Date()
        estimatedEndTime = Date().addingTimeInterval(program.duration)
        
        setLoading(true)
        clearError()
        
        do {
            // Phase 1: モック実装
            try await recordingService.startRecording(program: program)
            
            isRecording = true
            startProgressTimer()
            
        } catch {
            showError("録音を開始できませんでした: \(error.localizedDescription)")
            resetRecordingState()
        }
        
        setLoading(false)
    }
    
    /// 録音キャンセル
    func cancelRecording() {
        guard isRecording else { return }
        
        Task {
            do {
                await recordingService.cancelRecording()
                
                await MainActor.run {
                    stopProgressTimer()
                    resetRecordingState()
                    
                    // 録音キャンセル通知
                    NotificationCenter.default.post(
                        name: .recordingCancelled,
                        object: nil
                    )
                }
                
            } catch {
                await MainActor.run {
                    showError("録音の停止中にエラーが発生しました: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 録音完了処理
    func completeRecording() {
        stopProgressTimer()
        
        // 録音完了通知
        NotificationCenter.default.post(
            name: .recordingCompleted,
            object: currentProgram
        )
        
        resetRecordingState()
    }
    
    // MARK: - Private Methods
    /// 進捗タイマー開始
    private func startProgressTimer() {
        stopProgressTimer() // 既存のタイマーを停止
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateProgress()
            }
        }
    }
    
    /// 進捗タイマー停止
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    /// 進捗更新
    private func updateProgress() async {
        guard isRecording,
              let program = currentProgram,
              let startTime = recordingStartTime else { return }
        
        elapsedTime = Date().timeIntervalSince(startTime)
        
        // 進捗率計算
        let totalDuration = program.duration
        recordingProgress = min(elapsedTime / totalDuration, 1.0)
        
        // 録音完了チェック
        if elapsedTime >= totalDuration {
            completeRecording()
        }
    }
    
    /// 録音状態リセット
    private func resetRecordingState() {
        isRecording = false
        recordingProgress = 0.0
        elapsedTime = 0
        currentProgram = nil
        recordingStartTime = nil
        estimatedEndTime = nil
        clearError()
    }
}

// MARK: - Additional Notification Names
extension Notification.Name {
    /// 録音キャンセル通知
    static let recordingCancelled = Notification.Name("recordingCancelled")
}

// MARK: - Protocol Definition
/// 録音サービスプロトコル
protocol RecordingServiceProtocol {
    /// 録音開始
    /// - Parameter program: 録音する番組
    func startRecording(program: RadioProgram) async throws
    
    /// 録音キャンセル
    func cancelRecording() async
    
    /// 録音状態取得
    var isRecording: Bool { get }
}

// MARK: - Mock Service
/// モック録音サービス（Phase 1用）
class MockRecordingService: RecordingServiceProtocol {
    @Published var isRecording: Bool = false
    
    func startRecording(program: RadioProgram) async throws {
        // 開始処理のシミュレーション（1秒待機）
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Phase 1では常に成功
        isRecording = true
    }
    
    func cancelRecording() async {
        // キャンセル処理のシミュレーション（0.5秒待機）
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        isRecording = false
    }
}