//
//  RecordingProgressView.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import SwiftUI

/// 録音進捗ポップアップ
struct RecordingProgressView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel = RecordingViewModel()
    @EnvironmentObject private var navigationManager: NavigationManager
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 20) {
            // タイトル
            Text(viewModel.statusText)
                .font(.appTitle)
                .foregroundColor(.appPrimaryText)
            
            // 番組名
            Text(viewModel.currentProgram?.title ?? "")
                .font(.appHeadline)
                .foregroundColor(.appSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // プログレスバー
            ProgressView(value: viewModel.recordingProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 300)
                .accessibilityLabel("録音進捗 \(Int(viewModel.recordingProgress * 100))%")
            
            // 時間表示
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("経過時間")
                        .font(.appCaption)
                        .foregroundColor(.appSecondaryText)
                    
                    Text(viewModel.elapsedTimeString)
                        .font(.appMonospacedLarge)
                        .foregroundColor(.appPrimaryText)
                }
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("残り時間")
                        .font(.appCaption)
                        .foregroundColor(.appSecondaryText)
                    
                    Text(viewModel.remainingTimeString)
                        .font(.appMonospacedLarge)
                        .foregroundColor(.appPrimaryText)
                }
            }
            
            // キャンセルボタン
            Button("キャンセル") {
                viewModel.cancelRecording()
            }
            .buttonStyle(DangerButtonStyle())
            .accessibilityLabel("録音をキャンセル")
        }
        .frame(width: 400, height: 250)
        .padding(40)
        .background(Color.appUIBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .onReceive(NotificationCenter.default.publisher(for: .recordingCompleted)) { _ in
            navigationManager.showingRecordingProgress = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .recordingCancelled)) { _ in
            navigationManager.showingRecordingProgress = false
        }
        .alert("録音完了", isPresented: .constant(false)) {
            Button("OK") { }
        } message: {
            Text("録音が完了しました。")
        }
    }
}

// MARK: - Preview
#Preview {
    RecordingProgressView()
        .environmentObject(NavigationManager())
        .background(Color.black.opacity(0.5))
}