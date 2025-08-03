//
//  ProgramScheduleView.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/26.
//

import SwiftUI

/// 番組表表示ビュー
struct ProgramScheduleView: View {
    @StateObject private var viewModel = ProgramScheduleViewModel()
    @ObservedObject var recordingManager: RecordingManager
    @Binding var selectedStation: RadioStation?
    @State private var selectedDate: Date = Date()
    @State private var showingRecordingProgress = false
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            headerView
            
            // 番組リスト
            if let station = selectedStation {
                if viewModel.isLoading {
                    ProgressView("番組表を読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error {
                    ErrorView(message: error.localizedDescription) {
                        Task {
                            await viewModel.loadPrograms(for: station.id, date: selectedDate)
                        }
                    }
                } else {
                    programListView
                }
            } else {
                Text("放送局を選択してください")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: selectedStation) { _, newStation in
            if let station = newStation {
                Task {
                    await viewModel.loadPrograms(for: station.id, date: selectedDate)
                }
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            if let station = selectedStation {
                Task {
                    await viewModel.loadPrograms(for: station.id, date: newDate)
                }
            }
        }
        .onAppear {
            if let station = selectedStation {
                Task {
                    await viewModel.loadPrograms(for: station.id, date: selectedDate)
                }
            }
        }
        .sheet(isPresented: $showingRecordingProgress) {
            RecordingProgressView(recordingManager: recordingManager)
        }
    }
    
    // MARK: - Recording Methods
    
    /// 録音開始
    private func startRecording(program: RadioProgram) {
        guard let station = selectedStation else { 
            print("❌ [ProgramScheduleView] 録音エラー: 放送局が選択されていません")
            return 
        }
        
        print("🎙️ [ProgramScheduleView] 録音開始要求: \(program.title) (\(station.id))")
        print("⏰ [ProgramScheduleView] 録音時間: \(program.startTime) - \(program.endTime)")
        
        Task {
            do {
                // 出力ディレクトリ（デフォルトはDocuments/RecRadiko2）
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let outputDirectory = documentsPath.appendingPathComponent("RecRadiko2")
                
                print("📁 [ProgramScheduleView] 出力ディレクトリ: \(outputDirectory.path)")
                
                let settings = RecordingSettings(
                    stationId: station.id,
                    startTime: program.startTime,
                    endTime: program.endTime,
                    outputDirectory: outputDirectory
                )
                
                showingRecordingProgress = true
                let recordingId = try await recordingManager.startRecording(with: settings)
                print("✅ [ProgramScheduleView] 録音開始成功: ID=\(recordingId)")
                
            } catch {
                print("❌ [ProgramScheduleView] 録音開始エラー: \(error)")
                print("❌ [ProgramScheduleView] エラー詳細: \(error.localizedDescription)")
                if let recordingError = error as? RecordingError {
                    print("❌ [ProgramScheduleView] 録音エラータイプ: \(recordingError)")
                }
                showingRecordingProgress = false
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            // 日付選択プルダウン（過去1週間）
            Menu {
                ForEach(pastWeekDates, id: \.self) { date in
                    Button(DateFormatter.programDateFormatter.string(from: date)) {
                        selectedDate = date
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "calendar")
                    Text(DateFormatter.programDateFormatter.string(from: selectedDate))
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            
            Spacer()
            
            // リロードボタン
            Button(action: {
                if let station = selectedStation {
                    Task {
                        await viewModel.loadPrograms(for: station.id, date: selectedDate)
                    }
                }
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    /// 過去1週間の日付配列を生成
    private var pastWeekDates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0...6).compactMap { daysAgo in
            calendar.date(byAdding: .day, value: -daysAgo, to: today)
        }
    }
    
    // MARK: - Program List View
    private var programListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.programs.enumerated()), id: \.element.id) { index, program in
                    // 前の番組との間に空白時間がある場合、空白表示を追加
                    if index > 0 {
                        let previousProgram = viewModel.programs[index - 1]
                        let gap = program.startTime.timeIntervalSince(previousProgram.endTime)
                        let gapMinutes = Int(gap / 60)
                        
                        // 2分以上の空白のみ表示（微細な時間差は無視）
                        if gap > 120 { // 120秒 = 2分
                            gapView(from: previousProgram.endTime, to: program.startTime)
                        }
                    }
                    
                    ProgramRowView(
                        program: program, 
                        isRecording: viewModel.isRecording(program),
                        onRecordingStart: { startRecording(program: $0) }
                    )
                        .onTapGesture {
                            viewModel.selectedProgram = program
                        }
                    
                    Divider()
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    /// 番組間の空白時間を表示するビュー
    /// - Parameters:
    ///   - startTime: 空白開始時間
    ///   - endTime: 空白終了時間
    /// - Returns: 空白表示ビュー
    private func gapView(from startTime: Date, to endTime: Date) -> some View {
        let gapDuration = endTime.timeIntervalSince(startTime)
        let gapMinutes = Int(gapDuration / 60)
        
        return HStack {
            VStack(alignment: .trailing, spacing: 4) {
                Text(DateFormatter.timeFormatter.string(from: startTime))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                Text("↓")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(DateFormatter.timeFormatter.string(from: endTime))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("放送休止")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("\(gapMinutes)分間の休止時間")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
}

/// 番組行表示ビュー
struct ProgramRowView: View {
    let program: RadioProgram
    let isRecording: Bool
    let onRecordingStart: (RadioProgram) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 時間表示
            VStack(alignment: .trailing, spacing: 4) {
                Text(program.displayTime)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                
                Text("\(Int(program.duration / 60))分")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
            
            // 番組情報
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(program.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if program.isTimeFree {
                        Label("タイムフリー", systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if isRecording {
                        Label("録音中", systemImage: "record.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                }
                
                if !program.personalities.isEmpty {
                    Text(program.personalitiesText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(program.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 録音ボタン
            Button(action: {
                onRecordingStart(program)
            }) {
                Image(systemName: isRecording ? "stop.circle" : "record.circle")
                    .font(.title2)
                    .foregroundColor(isRecording ? .red : .primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}


// MARK: - Date Formatter Extension
extension DateFormatter {
    static let programDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter
    }()
    
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

// MARK: - Preview
struct ProgramScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        ProgramScheduleView(
            recordingManager: RecordingManager(),
            selectedStation: .constant(RadioStation.mockStations.first)
        )
            .frame(width: 600, height: 400)
    }
}