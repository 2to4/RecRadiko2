//
//  TimeConverterTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/25.
//

import Testing
import Foundation
@testable import RecRadiko2

@Suite("TimeConverter Tests")
struct TimeConverterTests {
    
    // MARK: - Radiko時刻文字列のパーステスト
    
    @Test("Radiko時刻文字列のパース - 正常系")
    func parseRadikoTimeString() {
        // Given
        let timeString = "20250725220000" // 2025年7月25日 22時00分00秒
        
        // When
        let date = TimeConverter.parseRadikoTime(timeString)
        
        // Then
        #expect(date != nil)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date!)
        #expect(components.year == 2025)
        #expect(components.month == 7)
        #expect(components.day == 25)
        #expect(components.hour == 22)
        #expect(components.minute == 0)
    }
    
    @Test("Radiko時刻文字列のパース - 異常系")
    func parseInvalidRadikoTimeString() {
        // Given & When & Then
        #expect(TimeConverter.parseRadikoTime("") == nil)
        #expect(TimeConverter.parseRadikoTime("invalid") == nil)
        #expect(TimeConverter.parseRadikoTime("2025072522") == nil) // 短すぎる
        #expect(TimeConverter.parseRadikoTime("20250725220000123") == nil) // 長すぎる
        #expect(TimeConverter.parseRadikoTime("20251332220000") == nil) // 無効な月
    }
    
    // MARK: - 25時間表記フォーマットテスト
    
    @Test("25時間表記フォーマット - 通常時間")
    func formatNormalTime() {
        // Given
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2025, month: 7, day: 25, hour: 14, minute: 30))!
        
        // When
        let formattedTime = TimeConverter.formatProgramTime(date)
        
        // Then
        #expect(formattedTime == "14:30")
    }
    
    @Test("25時間表記フォーマット - 深夜時間")
    func formatMidnightTime() {
        // Given
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2025, month: 7, day: 26, hour: 2, minute: 30))!
        
        // When
        let formattedTime = TimeConverter.formatProgramTime(date)
        
        // Then
        #expect(formattedTime == "26:30") // 2時30分 → 26時30分
    }
    
    @Test("25時間表記フォーマット - 境界値テスト")
    func formatBoundaryTimes() {
        let calendar = Calendar.current
        
        // 4時59分（まだ深夜扱い）
        let date1 = calendar.date(from: DateComponents(year: 2025, month: 7, day: 26, hour: 4, minute: 59))!
        #expect(TimeConverter.formatProgramTime(date1) == "28:59")
        
        // 5時00分（通常時間扱い）
        let date2 = calendar.date(from: DateComponents(year: 2025, month: 7, day: 26, hour: 5, minute: 0))!
        #expect(TimeConverter.formatProgramTime(date2) == "05:00")
        
        // 0時00分（深夜扱い）
        let date3 = calendar.date(from: DateComponents(year: 2025, month: 7, day: 26, hour: 0, minute: 0))!
        #expect(TimeConverter.formatProgramTime(date3) == "24:00")
    }
    
    // MARK: - 番組放送日取得テスト
    
    @Test("番組の放送日取得 - 通常番組")
    func getProgramDateNormal() {
        // Given
        let calendar = Calendar.current
        let startTime = calendar.date(from: DateComponents(year: 2025, month: 7, day: 25, hour: 14, minute: 0))!
        let program = createTestProgram(startTime: startTime)
        
        // When
        let programDate = TimeConverter.getProgramDate(program)
        
        // Then
        let programComponents = calendar.dateComponents([.year, .month, .day], from: programDate)
        #expect(programComponents.year == 2025)
        #expect(programComponents.month == 7)
        #expect(programComponents.day == 25)
    }
    
    @Test("番組の放送日取得 - 深夜番組")
    func getProgramDateMidnight() {
        // Given
        let calendar = Calendar.current
        let startTime = calendar.date(from: DateComponents(year: 2025, month: 7, day: 26, hour: 2, minute: 0))!
        let program = createTestProgram(startTime: startTime)
        
        // When
        let programDate = TimeConverter.getProgramDate(program)
        
        // Then
        let programComponents = calendar.dateComponents([.year, .month, .day], from: programDate)
        #expect(programComponents.year == 2025)
        #expect(programComponents.month == 7)
        #expect(programComponents.day == 25) // 前日扱い
    }
    
    @Test("指定日の番組判定")
    func isProgramOnDate() {
        // Given
        let calendar = Calendar.current
        let targetDate = calendar.date(from: DateComponents(year: 2025, month: 7, day: 25))!
        
        // 深夜2時の番組（7/26 02:00だが7/25の番組扱い）
        let midnightTime = calendar.date(from: DateComponents(year: 2025, month: 7, day: 26, hour: 2, minute: 0))!
        let midnightProgram = createTestProgram(startTime: midnightTime)
        
        // 通常時間の番組（7/25 14:00）
        let normalTime = calendar.date(from: DateComponents(year: 2025, month: 7, day: 25, hour: 14, minute: 0))!
        let normalProgram = createTestProgram(startTime: normalTime)
        
        // 翌日の番組（7/26 14:00）
        let nextDayTime = calendar.date(from: DateComponents(year: 2025, month: 7, day: 26, hour: 14, minute: 0))!
        let nextDayProgram = createTestProgram(startTime: nextDayTime)
        
        // When & Then
        #expect(TimeConverter.isProgramOnDate(midnightProgram, date: targetDate) == true)
        #expect(TimeConverter.isProgramOnDate(normalProgram, date: targetDate) == true)
        #expect(TimeConverter.isProgramOnDate(nextDayProgram, date: targetDate) == false)
    }
    
    // MARK: - 継続時間フォーマットテスト
    
    @Test("継続時間のフォーマット")
    func formatDuration() {
        // 30分
        #expect(TimeConverter.formatDuration(1800) == "30分")
        
        // 1時間
        #expect(TimeConverter.formatDuration(3600) == "1時間0分")
        
        // 1時間30分
        #expect(TimeConverter.formatDuration(5400) == "1時間30分")
        
        // 2時間15分
        #expect(TimeConverter.formatDuration(8100) == "2時間15分")
        
        // 0分
        #expect(TimeConverter.formatDuration(0) == "0分")
    }
    
    // MARK: - 日付範囲生成テスト
    
    @Test("過去1週間の日付生成")
    func generatePastWeekDates() {
        // When
        let dates = TimeConverter.generatePastWeekDates()
        
        // Then
        #expect(dates.count == 7)
        
        // 日付が降順になっていることを確認
        for i in 0..<dates.count-1 {
            #expect(dates[i] >= dates[i+1])
        }
        
        // 最初の日付が今日の放送日であることを確認
        let today = Date().broadcastDate
        let calendar = Calendar.current
        #expect(calendar.isDate(dates[0], inSameDayAs: today))
    }
    
    @Test("番組表取得範囲の計算")
    func getProgramRange() {
        // Given
        let calendar = Calendar.current
        let testDate = calendar.date(from: DateComponents(year: 2025, month: 7, day: 25))!
        
        // When
        let range = TimeConverter.getProgramRange(for: testDate)
        
        // Then
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour], from: range.start)
        let endComponents = calendar.dateComponents([.year, .month, .day, .hour], from: range.end)
        
        // 開始時刻: 7/25 05:00
        #expect(startComponents.year == 2025)
        #expect(startComponents.month == 7)
        #expect(startComponents.day == 25)
        #expect(startComponents.hour == 5)
        
        // 終了時刻: 7/26 05:00
        #expect(endComponents.year == 2025)
        #expect(endComponents.month == 7)
        #expect(endComponents.day == 26)
        #expect(endComponents.hour == 5)
        
        // 24時間の範囲であることを確認
        #expect(range.end.timeIntervalSince(range.start) == 24 * 3600)
    }
    
    // MARK: - バリデーションテスト
    
    @Test("時刻文字列の妥当性チェック")
    func isValidRadikoTimeString() {
        // 正常系
        #expect(TimeConverter.isValidRadikoTimeString("20250725220000") == true)
        #expect(TimeConverter.isValidRadikoTimeString("20250101000000") == true)
        #expect(TimeConverter.isValidRadikoTimeString("20251231235959") == true)
        
        // 異常系
        #expect(TimeConverter.isValidRadikoTimeString("") == false)
        #expect(TimeConverter.isValidRadikoTimeString("2025072522") == false) // 短い
        #expect(TimeConverter.isValidRadikoTimeString("202507252200001") == false) // 長い
        #expect(TimeConverter.isValidRadikoTimeString("2025072522000a") == false) // 文字が含まれる
        #expect(TimeConverter.isValidRadikoTimeString("20251332220000") == false) // 無効な日付
    }
    
    @Test("番組時間の重複チェック")
    func isTimeOverlapping() {
        let calendar = Calendar.current
        let baseTime = calendar.date(from: DateComponents(year: 2025, month: 7, day: 25, hour: 14, minute: 0))!
        
        // 14:00-15:00の番組
        let program1 = createTestProgram(
            startTime: baseTime,
            endTime: baseTime.addingTimeInterval(3600)
        )
        
        // 14:30-15:30の番組（重複）
        let program2 = createTestProgram(
            startTime: baseTime.addingTimeInterval(1800),
            endTime: baseTime.addingTimeInterval(5400)
        )
        
        // 15:00-16:00の番組（隣接、重複なし）
        let program3 = createTestProgram(
            startTime: baseTime.addingTimeInterval(3600),
            endTime: baseTime.addingTimeInterval(7200)
        )
        
        // 16:00-17:00の番組（完全に分離）
        let program4 = createTestProgram(
            startTime: baseTime.addingTimeInterval(7200),
            endTime: baseTime.addingTimeInterval(10800)
        )
        
        // When & Then
        #expect(TimeConverter.isTimeOverlapping(program1, program2) == true)  // 重複
        #expect(TimeConverter.isTimeOverlapping(program1, program3) == false) // 隣接
        #expect(TimeConverter.isTimeOverlapping(program1, program4) == false) // 分離
        #expect(TimeConverter.isTimeOverlapping(program2, program3) == true)  // 重複
    }
    
    // MARK: - Date Extension テスト
    
    @Test("Date.broadcastDate - 深夜時間")
    func dateBroadcastDateMidnight() {
        let calendar = Calendar.current
        let midnightDate = calendar.date(from: DateComponents(year: 2025, month: 7, day: 26, hour: 2, minute: 30))!
        
        let broadcastDate = midnightDate.broadcastDate
        let components = calendar.dateComponents([.year, .month, .day], from: broadcastDate)
        
        #expect(components.year == 2025)
        #expect(components.month == 7)
        #expect(components.day == 25) // 前日
    }
    
    @Test("Date.broadcastDate - 通常時間")
    func dateBroadcastDateNormal() {
        let calendar = Calendar.current
        let normalDate = calendar.date(from: DateComponents(year: 2025, month: 7, day: 25, hour: 14, minute: 30))!
        
        let broadcastDate = normalDate.broadcastDate
        let components = calendar.dateComponents([.year, .month, .day], from: broadcastDate)
        
        #expect(components.year == 2025)
        #expect(components.month == 7)
        #expect(components.day == 25) // 同日
    }
    
    @Test("Date.isMidnightHour")
    func dateIsMidnightHour() {
        let calendar = Calendar.current
        
        // 深夜時間（0-4時）
        for hour in 0..<5 {
            let date = calendar.date(from: DateComponents(year: 2025, month: 7, day: 25, hour: hour))!
            #expect(date.isMidnightHour == true)
        }
        
        // 通常時間（5-23時）
        for hour in 5..<24 {
            let date = calendar.date(from: DateComponents(year: 2025, month: 7, day: 25, hour: hour))!
            #expect(date.isMidnightHour == false)
        }
    }
    
    // MARK: - ヘルパーメソッド
    
    private func createTestProgram(startTime: Date, endTime: Date? = nil) -> RadioProgram {
        let finalEndTime = endTime ?? startTime.addingTimeInterval(3600)
        return RadioProgram(
            id: "test_program",
            title: "テスト番組",
            description: "テスト用番組",
            startTime: startTime,
            endTime: finalEndTime,
            personalities: ["テストパーソナリティ"],
            stationId: "TEST_STATION",
            imageURL: nil,
            isTimeFree: true
        )
    }
}