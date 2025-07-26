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
        isLoading = true
        error = nil
        
        do {
            let fetchedPrograms = try await apiService.fetchPrograms(stationId: stationId, date: date)
            
            // 時間順にソート
            programs = fetchedPrograms.sorted { $0.startTime < $1.startTime }
            
        } catch {
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