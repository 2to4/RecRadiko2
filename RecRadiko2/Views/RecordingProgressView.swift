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
    
    // MARK: - Body
    var body: some View {
        mainContent
            .frame(width: 400, height: 250)
            .padding(40)
            .background(Color.appUIBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .onChange(of: recordingManager.currentProgress?.state) { _, state in
                switch state {
                case .completed:
                    dismiss()
                case .failed:
                    dismiss()
                default:
                    break
                }
            }
    }
    
    private var mainContent: some View {
        VStack(spacing: 20) {
            titleView
            programView
            progressBarView
            progressInfoView
            cancelButtonView
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
                .font(.appMonospacedLarge)
                .foregroundColor(.appPrimaryText)
        }
    }
    
    private var progressPercentView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("進捗率")
                .font(.appCaption)
                .foregroundColor(.appSecondaryText)
            
            Text("\(Int(progressValue * 100))%")
                .font(.appMonospacedLarge)
                .foregroundColor(.appPrimaryText)
        }
    }
    
    private var cancelButtonView: some View {
        Button("キャンセル") {
            recordingManager.stopAllRecordings()
            dismiss()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel("録音をキャンセル")
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