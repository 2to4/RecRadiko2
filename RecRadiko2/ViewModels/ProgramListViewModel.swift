//
//  ProgramListViewModel.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import Foundation
import Combine

/// 番組一覧画面のViewModel
@MainActor
final class ProgramListViewModel: BaseViewModel {
    // MARK: - Published Properties
    /// 現在選択中の放送局
    @Published var currentStation: RadioStation?
    
    /// 番組一覧
    @Published var programs: [RadioProgram] = []
    
    /// 選択中の日付
    @Published var selectedDate: Date = Date()
    
    /// 選択中の番組
    @Published var selectedProgram: RadioProgram?
    
    // MARK: - Dependencies
    private let apiService: RadikoAPIServiceProtocol
    
    // MARK: - Computed Properties
    /// 利用可能な日付一覧（過去1週間）
    var availableDates: [Date] {
        (0..<7).compactMap { 
            Calendar.current.date(byAdding: .day, value: -$0, to: Date()) 
        }
    }
    
    /// 録音開始可能かどうか
    var canStartRecording: Bool {
        selectedProgram != nil && currentStation != nil
    }
    
    // MARK: - 初期化
    init(apiService: RadikoAPIServiceProtocol = MockRadikoAPIService()) {
        self.apiService = apiService
        super.init()
    }
    
    // MARK: - セットアップ
    override func setupNotifications() {
        // 放送局選択通知の受信
        NotificationCenter.default.publisher(for: .stationSelected)
            .compactMap { $0.object as? RadioStation }
            .sink { [weak self] station in
                Task { @MainActor in
                    await self?.setStation(station)
                }
            }
            .store(in: &cancellables)
        
        // 日付変更時の自動リロード
        $selectedDate
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadPrograms()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    /// 放送局を設定
    /// - Parameter station: 設定する放送局
    func setStation(_ station: RadioStation) async {
        currentStation = station
        selectedProgram = nil // 番組選択をリセット
        await loadPrograms()
    }
    
    /// 番組一覧の読み込み
    func loadPrograms() async {
        guard let station = currentStation else { 
            programs = []
            return 
        }
        
        setLoading(true)
        clearError()
        
        do {
            let fetchedPrograms = try await apiService.fetchPrograms(
                stationId: station.id, 
                date: selectedDate
            )
            programs = fetchedPrograms.sorted { $0.startTime < $1.startTime }
        } catch {
            showError(error.localizedDescription)
            programs = []
        }
        
        setLoading(false)
    }
    
    /// 日付選択
    /// - Parameter date: 選択する日付
    func selectDate(_ date: Date) {
        guard !Calendar.current.isDate(date, inSameDayAs: selectedDate) else { return }
        selectedDate = date
        selectedProgram = nil // 番組選択をリセット
        // setupNotifications()のsinkで自動的にloadPrograms()が呼ばれる
    }
    
    /// 番組選択
    /// - Parameter program: 選択する番組
    func selectProgram(_ program: RadioProgram) {
        selectedProgram = program
    }
    
    /// 録音開始
    func startRecording() {
        guard let program = selectedProgram else { 
            showError("番組を選択してください")
            return 
        }
        
        // 録音開始通知
        NotificationCenter.default.post(
            name: .recordingStarted,
            object: program
        )
    }
    
    /// 前の日付に移動
    func goToPreviousDate() {
        guard let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate),
              availableDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: previousDate) }) else {
            return
        }
        selectDate(previousDate)
    }
    
    /// 次の日付に移動
    func goToNextDate() {
        guard let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate),
              nextDate <= Date() else { // 未来の日付は選択不可
            return
        }
        selectDate(nextDate)
    }
    
    /// 放送局一覧に戻る
    func backToStationList() {
        currentStation = nil
        programs = []
        selectedProgram = nil
        
        // タブ切り替え通知（Phase 1では直接ContentViewで処理）
        NotificationCenter.default.post(
            name: .backToStationList,
            object: nil
        )
    }
}

// MARK: - Additional Notification Names
extension Notification.Name {
    /// 放送局一覧に戻る通知
    static let backToStationList = Notification.Name("backToStationList")
}