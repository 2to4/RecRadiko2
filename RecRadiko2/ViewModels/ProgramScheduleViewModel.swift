//
//  ProgramScheduleViewModel.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/26.
//

import SwiftUI
import Combine

/// 番組表表示用ViewModel
@MainActor
class ProgramScheduleViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var programs: [RadioProgram] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedProgram: RadioProgram?
    @Published var recordingPrograms: Set<String> = []
    
    // MARK: - Private Properties
    private let apiService: RadikoAPIServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(apiService: RadikoAPIServiceProtocol? = nil) {
        self.apiService = apiService ?? RadikoAPIService()
    }
    
    // MARK: - Public Methods
    
    /// 番組表を読み込む
    /// - Parameters:
    ///   - stationId: 放送局ID
    ///   - date: 対象日
    func loadPrograms(for stationId: String, date: Date) async {
        print("🔄 [ProgramScheduleViewModel] 番組読み込み開始 - 放送局ID: \(stationId), 日付: \(date)")
        isLoading = true
        error = nil
        
        do {
            let fetchedPrograms = try await apiService.fetchPrograms(stationId: stationId, date: date)
            print("✅ [ProgramScheduleViewModel] 番組取得成功 - 件数: \(fetchedPrograms.count)")
            
            // 時間順にソート
            programs = fetchedPrograms.sorted { $0.startTime < $1.startTime }
            
            if programs.isEmpty {
                print("⚠️ [ProgramScheduleViewModel] 番組データが空です")
            } else {
                print("📋 [ProgramScheduleViewModel] 最初の番組: \(programs.first?.title ?? "不明")")
                
                // 番組間の時間的空白をチェック
                for i in 0..<programs.count-1 {
                    let currentProgram = programs[i]
                    let nextProgram = programs[i+1]
                    
                    let gap = nextProgram.startTime.timeIntervalSince(currentProgram.endTime)
                    let gapMinutes = Int(gap / 60)
                    
                    if gap > 120 { // 2分以上の空白のみ報告
                        print("⚠️ [ProgramScheduleViewModel] 番組間空白発見: \(currentProgram.title) -> \(nextProgram.title), 空白時間: \(gapMinutes)分")
                    } else if gap > 0 {
                        print("ℹ️ [ProgramScheduleViewModel] 微細な間隔: \(currentProgram.title) -> \(nextProgram.title), \(gapMinutes)分（無視）")
                    }
                }
            }
            
        } catch {
            print("❌ [ProgramScheduleViewModel] エラー: \(error)")
            self.error = error
            programs = []
        }
        
        isLoading = false
    }
    
    /// 番組が録音中かチェック
    /// - Parameter program: チェック対象の番組
    /// - Returns: 録音中の場合true
    func isRecording(_ program: RadioProgram) -> Bool {
        recordingPrograms.contains(program.id)
    }
    
    /// 録音開始
    /// - Parameter program: 録音対象の番組
    func startRecording(_ program: RadioProgram) {
        recordingPrograms.insert(program.id)
        // TODO: 実際の録音処理を実装
    }
    
    /// 録音停止
    /// - Parameter program: 停止対象の番組
    func stopRecording(_ program: RadioProgram) {
        recordingPrograms.remove(program.id)
        // TODO: 実際の録音停止処理を実装
    }
    
    /// 本日の番組表を読み込む
    /// - Parameter stationId: 放送局ID
    func loadTodayPrograms(for stationId: String) async {
        await loadPrograms(for: stationId, date: Date())
    }
    
    /// 指定日の番組数を取得
    /// - Parameters:
    ///   - stationId: 放送局ID
    ///   - date: 対象日
    /// - Returns: 番組数
    func getProgramCount(for stationId: String, date: Date) async -> Int {
        do {
            let programs = try await apiService.fetchPrograms(stationId: stationId, date: date)
            return programs.count
        } catch {
            return 0
        }
    }
}