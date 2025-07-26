//
//  ProgramScheduleViewModelTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/26.
//

import Testing
import Foundation
@testable import RecRadiko2

@Suite("ProgramScheduleViewModel Tests", .serialized)
struct ProgramScheduleViewModelTests {
    
    // MARK: - Test Helpers
    
    /// テスト用モックAPIサービス
    class MockRadikoAPIService: RadikoAPIServiceProtocol {
        var shouldThrowError = false
        var errorToThrow: Error = RadikoError.networkError(NSError(domain: "Test", code: -1, userInfo: [NSLocalizedDescriptionKey: "テストエラー"]))
        var programsToReturn: [RadioProgram] = []
        var fetchProgramsCallCount = 0
        
        func fetchStations(for areaId: String) async throws -> [RadioStation] {
            return []
        }
        
        func fetchPrograms(stationId: String, date: Date) async throws -> [RadioProgram] {
            fetchProgramsCallCount += 1
            
            if shouldThrowError {
                throw errorToThrow
            }
            
            return programsToReturn
        }
    }
    
    // MARK: - Tests
    
    @Test("番組表読み込み成功")
    @MainActor
    func testLoadProgramsSuccess() async throws {
        // Arrange
        let mockAPI = MockRadikoAPIService()
        let testPrograms = [
            RadioProgram(
                id: "prog1",
                title: "テスト番組1",
                description: "説明1",
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600),
                personalities: ["パーソナリティ1"],
                stationId: "TBS"
            ),
            RadioProgram(
                id: "prog2",
                title: "テスト番組2",
                description: "説明2",
                startTime: Date().addingTimeInterval(3600),
                endTime: Date().addingTimeInterval(7200),
                personalities: ["パーソナリティ2"],
                stationId: "TBS"
            )
        ]
        mockAPI.programsToReturn = testPrograms
        
        let viewModel = ProgramScheduleViewModel(apiService: mockAPI)
        
        // Act
        await viewModel.loadPrograms(for: "TBS", date: Date())
        
        // Assert
        #expect(mockAPI.fetchProgramsCallCount == 1)
        #expect(viewModel.programs.count == 2)
        #expect(viewModel.programs[0].id == "prog1")
        #expect(viewModel.programs[1].id == "prog2")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.error == nil)
    }
    
    @Test("番組表読み込みエラー")
    @MainActor
    func testLoadProgramsError() async throws {
        // Arrange
        let mockAPI = MockRadikoAPIService()
        mockAPI.shouldThrowError = true
        mockAPI.errorToThrow = RadikoError.authenticationFailed
        
        let viewModel = ProgramScheduleViewModel(apiService: mockAPI)
        
        // Act
        await viewModel.loadPrograms(for: "TBS", date: Date())
        
        // Assert
        #expect(mockAPI.fetchProgramsCallCount == 1)
        #expect(viewModel.programs.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.error != nil)
    }
    
    @Test("番組が時間順にソートされる")
    @MainActor
    func testProgramsSortedByTime() async throws {
        // Arrange
        let mockAPI = MockRadikoAPIService()
        let now = Date()
        let testPrograms = [
            RadioProgram(
                id: "prog3",
                title: "3番目の番組",
                description: "説明3",
                startTime: now.addingTimeInterval(7200), // 2時間後
                endTime: now.addingTimeInterval(10800),
                personalities: [],
                stationId: "TBS"
            ),
            RadioProgram(
                id: "prog1",
                title: "1番目の番組",
                description: "説明1",
                startTime: now, // 現在
                endTime: now.addingTimeInterval(3600),
                personalities: [],
                stationId: "TBS"
            ),
            RadioProgram(
                id: "prog2",
                title: "2番目の番組",
                description: "説明2",
                startTime: now.addingTimeInterval(3600), // 1時間後
                endTime: now.addingTimeInterval(7200),
                personalities: [],
                stationId: "TBS"
            )
        ]
        mockAPI.programsToReturn = testPrograms
        
        let viewModel = ProgramScheduleViewModel(apiService: mockAPI)
        
        // Act
        await viewModel.loadPrograms(for: "TBS", date: Date())
        
        // Assert
        #expect(viewModel.programs.count == 3)
        #expect(viewModel.programs[0].id == "prog1")
        #expect(viewModel.programs[1].id == "prog2")
        #expect(viewModel.programs[2].id == "prog3")
    }
    
    @Test("録音状態管理")
    @MainActor
    func testRecordingStateManagement() async throws {
        // Arrange
        let viewModel = ProgramScheduleViewModel()
        let testProgram = RadioProgram(
            id: "prog1",
            title: "テスト番組",
            description: "説明",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            personalities: [],
            stationId: "TBS"
        )
        
        // Act & Assert - 初期状態
        #expect(viewModel.isRecording(testProgram) == false)
        
        // Act & Assert - 録音開始
        viewModel.startRecording(testProgram)
        #expect(viewModel.isRecording(testProgram) == true)
        
        // Act & Assert - 録音停止
        viewModel.stopRecording(testProgram)
        #expect(viewModel.isRecording(testProgram) == false)
    }
    
    @Test("本日の番組表読み込み")
    @MainActor
    func testLoadTodayPrograms() async throws {
        // Arrange
        let mockAPI = MockRadikoAPIService()
        mockAPI.programsToReturn = [
            RadioProgram(
                id: "prog1",
                title: "今日の番組",
                description: "説明",
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600),
                personalities: [],
                stationId: "TBS"
            )
        ]
        
        let viewModel = ProgramScheduleViewModel(apiService: mockAPI)
        
        // Act
        await viewModel.loadTodayPrograms(for: "TBS")
        
        // Assert
        #expect(mockAPI.fetchProgramsCallCount == 1)
        #expect(viewModel.programs.count == 1)
        #expect(viewModel.programs[0].title == "今日の番組")
    }
    
    @Test("番組数取得")
    @MainActor
    func testGetProgramCount() async throws {
        // Arrange
        let mockAPI = MockRadikoAPIService()
        mockAPI.programsToReturn = [
            RadioProgram(
                id: "prog1",
                title: "番組1",
                description: "説明1",
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600),
                personalities: [],
                stationId: "TBS"
            ),
            RadioProgram(
                id: "prog2",
                title: "番組2",
                description: "説明2",
                startTime: Date().addingTimeInterval(3600),
                endTime: Date().addingTimeInterval(7200),
                personalities: [],
                stationId: "TBS"
            )
        ]
        
        let viewModel = ProgramScheduleViewModel(apiService: mockAPI)
        
        // Act
        let count = await viewModel.getProgramCount(for: "TBS", date: Date())
        
        // Assert
        #expect(count == 2)
    }
    
    @Test("番組数取得エラー時は0を返す")
    @MainActor
    func testGetProgramCountReturnsZeroOnError() async throws {
        // Arrange
        let mockAPI = MockRadikoAPIService()
        mockAPI.shouldThrowError = true
        
        let viewModel = ProgramScheduleViewModel(apiService: mockAPI)
        
        // Act
        let count = await viewModel.getProgramCount(for: "TBS", date: Date())
        
        // Assert
        #expect(count == 0)
    }
}