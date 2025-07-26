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
    @State private var showingDatePicker = false
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
        guard let station = selectedStation else { return }
        
        Task {
            do {
                // 出力ディレクトリ（デフォルトはDocuments/RecRadiko2）
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let outputDirectory = documentsPath.appendingPathComponent("RecRadiko2")
                
                let settings = RecordingSettings(
                    stationId: station.id,
                    startTime: program.startTime,
                    endTime: program.endTime,
                    outputDirectory: outputDirectory
                )
                
                showingRecordingProgress = true
                _ = try await recordingManager.startRecording(with: settings)
                
            } catch {
                print("録音開始エラー: \(error)")
                // エラーアラート表示（簡易実装）
                showingRecordingProgress = false
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            // 日付選択ボタン
            Button(action: { showingDatePicker.toggle() }) {
                HStack {
                    Image(systemName: "calendar")
                    Text(DateFormatter.programDateFormatter.string(from: selectedDate))
                }
            }
            .popover(isPresented: $showingDatePicker) {
                DatePicker("日付を選択", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .frame(width: 320, height: 400)
            }
            
            Spacer()
            
            // 今日ボタン
            Button("今日") {
                selectedDate = Date()
            }
            .disabled(Calendar.current.isDateInToday(selectedDate))
            
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
    
    // MARK: - Program List View
    private var programListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.programs) { program in
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