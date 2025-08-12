//
//  RecordingProgressView.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import SwiftUI

/// 録音進捗ポップアップ
struct RecordingProgressView: View {
    // MARK: - Properties
    @ObservedObject var recordingManager: RecordingManager
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    
    // MARK: - Body
    var body: some View {
        mainContent
            .frame(width: 450, height: showError ? 350 : 250)
            .padding(40)
            .background(Color.appUIBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .onChange(of: recordingManager.currentProgress?.state) { _, state in
                switch state {
                case .completed:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }
                case .failed(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                    print("❌ [RecordingProgressView] エラー表示: \(errorMessage)")
                default:
                    break
                }
            }
    }
    
    private var mainContent: some View {
        VStack(spacing: 20) {
            titleView
            programView
            
            if showError {
                errorView
            } else {
                progressBarView
                progressInfoView
            }
            
            buttonView
        }
    }
    
    private var titleView: some View {
        Text(statusText)
            .font(.appTitle)
            .foregroundColor(.appPrimaryText)
    }
    
    private var programView: some View {
        Text(recordingManager.currentProgress?.currentProgram?.title ?? "録音中...")
            .font(.appHeadline)
            .foregroundColor(.appSecondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var progressBarView: some View {
        ProgressView(value: progressValue)
            .progressViewStyle(LinearProgressViewStyle())
            .frame(width: 300)
            .accessibilityLabel("録音進捗 \(Int(progressValue * 100))%")
    }
    
    @ViewBuilder
    private var progressInfoView: some View {
        if let progress = recordingManager.currentProgress {
            HStack(spacing: 20) {
                downloadedSegmentsView(progress)
                progressPercentView
            }
        }
    }
    
    private func downloadedSegmentsView(_ progress: RecordingProgress) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ダウンロード済み")
                .font(.appCaption)
                .foregroundColor(.appSecondaryText)
            
            Text("\(progress.downloadedSegments)/\(progress.totalSegments)")
                .font(.appTimerDisplay)
                .foregroundColor(.appPrimaryText)
        }
    }
    
    private var progressPercentView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("進捗率")
                .font(.appCaption)
                .foregroundColor(.appSecondaryText)
            
            Text("\(Int(progressValue * 100))%")
                .font(.appTimerDisplay)
                .foregroundColor(.appPrimaryText)
        }
    }
    
    // エラー表示ビュー
    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("録音エラー")
                .font(.headline)
                .foregroundColor(.red)
            
            ScrollView {
                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 100)
        }
    }
    
    // ボタンビュー（エラー時と通常時で切り替え）
    private var buttonView: some View {
        HStack(spacing: 16) {
            if showError {
                Button("閉じる") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("再試行") {
                    showError = false
                    errorMessage = ""
                    // 再試行ロジックは今後実装
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button("キャンセル") {
                    recordingManager.stopAllRecordings()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel("録音をキャンセル")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        guard let progress = recordingManager.currentProgress else {
            return "準備中..."
        }
        
        switch progress.state {
        case .idle:
            return "待機中"
        case .authenticating:
            return "認証中..."
        case .fetchingPlaylist:
            return "プレイリスト取得中..."
        case .downloading:
            return "ダウンロード中..."
        case .saving:
            return "保存中..."
        case .completed:
            return "完了"
        case .failed:
            return "エラー"
        }
    }
    
    private var progressValue: Double {
        recordingManager.currentProgress?.progressPercentage ?? 0.0
    }
}

// MARK: - Preview
#Preview {
    RecordingProgressView(recordingManager: RecordingManager())
        .background(Color.black.opacity(0.5))
}