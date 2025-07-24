//
//  StationListViewModel.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import Foundation
import Combine

/// 放送局一覧画面のViewModel
@MainActor
final class StationListViewModel: BaseViewModel {
    // MARK: - Published Properties
    /// 放送局一覧
    @Published var stations: [RadioStation] = []
    
    /// 選択中の地域
    @Published var selectedArea: Area = Area.tokyo
    
    /// 利用可能な地域一覧
    @Published var areas: [Area] = Area.allCases
    
    // MARK: - Dependencies
    /// API サービス（Phase 2で実装予定）
    private let apiService: RadikoAPIServiceProtocol
    
    // MARK: - 初期化
    init(apiService: RadikoAPIServiceProtocol = MockRadikoAPIService()) {
        self.apiService = apiService
        super.init()
        loadInitialData()
    }
    
    // MARK: - セットアップ
    override func setupNotifications() {
        // 地域変更時の自動リロード
        $selectedArea
            .dropFirst() // 初期値をスキップ
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadStations()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    /// 初期データの読み込み
    func loadInitialData() {
        // AppStorageから前回選択した地域を復元（Phase 1では東京固定）
        selectedArea = Area.tokyo
        Task {
            await loadStations()
        }
    }
    
    /// 放送局一覧の読み込み
    func loadStations() async {
        setLoading(true)
        clearError()
        
        do {
            let fetchedStations = try await apiService.fetchStations(for: selectedArea.id)
            stations = fetchedStations
        } catch {
            showError(error.localizedDescription)
            stations = []
        }
        
        setLoading(false)
    }
    
    /// 地域選択
    /// - Parameter area: 選択する地域
    func selectArea(_ area: Area) {
        guard area != selectedArea else { return }
        selectedArea = area
        // setupNotifications()のsinkで自動的にloadStations()が呼ばれる
    }
    
    /// 放送局選択
    /// - Parameter station: 選択された放送局
    func selectStation(_ station: RadioStation) {
        // 番組一覧画面への遷移通知
        NotificationCenter.default.post(
            name: .stationSelected,
            object: station
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    /// 放送局選択通知
    static let stationSelected = Notification.Name("stationSelected")
    /// 録音開始通知
    static let recordingStarted = Notification.Name("recordingStarted")
    /// 録音完了通知
    static let recordingCompleted = Notification.Name("recordingCompleted")
}

// MARK: - Protocol Definition
/// Radiko API サービスプロトコル
protocol RadikoAPIServiceProtocol {
    /// 指定地域の放送局一覧を取得
    /// - Parameter areaId: 地域ID
    /// - Returns: 放送局配列
    func fetchStations(for areaId: String) async throws -> [RadioStation]
    
    /// 指定放送局・日付の番組一覧を取得
    /// - Parameters:
    ///   - stationId: 放送局ID
    ///   - date: 対象日付
    /// - Returns: 番組配列
    func fetchPrograms(stationId: String, date: Date) async throws -> [RadioProgram]
}

// MARK: - Mock Service
/// モック API サービス（Phase 1用）
class MockRadikoAPIService: RadikoAPIServiceProtocol {
    /// エラーを返すかどうか（テスト用）
    var shouldReturnError = false
    /// ネットワーク遅延シミュレーション
    var networkDelay: TimeInterval = 0.5
    /// モック放送局データ
    var mockStations: [RadioStation] = RadioStation.mockStations
    /// モック番組データ
    var mockPrograms: [RadioProgram] = RadioProgram.mockPrograms
    
    func fetchStations(for areaId: String) async throws -> [RadioStation] {
        // ネットワーク遅延をシミュレート
        try await Task.sleep(nanoseconds: UInt64(networkDelay * 1_000_000_000))
        
        if shouldReturnError {
            throw AppError.networkError("番組表を取得できませんでした")
        }
        
        return mockStations.filter { $0.areaId == areaId }
    }
    
    func fetchPrograms(stationId: String, date: Date) async throws -> [RadioProgram] {
        try await Task.sleep(nanoseconds: UInt64(networkDelay * 1_000_000_000))
        
        if shouldReturnError {
            throw AppError.networkError("番組表を取得できませんでした")
        }
        
        return mockPrograms.filter { $0.stationId == stationId }
    }
}