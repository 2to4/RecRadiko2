//
//  RadioProgram.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import Foundation

/// 番組情報を表すモデル
struct RadioProgram: Identifiable, Hashable, Codable {
    let id: String              // 番組ID
    let title: String           // 番組名
    let description: String     // 番組説明
    let startTime: Date         // 開始時刻
    let endTime: Date           // 終了時刻
    let personalities: [String] // 出演者リスト
    let stationId: String       // 所属放送局ID
    
    init(id: String, title: String, description: String, startTime: Date, endTime: Date, personalities: [String], stationId: String) {
        self.id = id
        self.title = title
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.personalities = personalities
        self.stationId = stationId
    }
}

// MARK: - Computed Properties
extension RadioProgram {
    /// 番組の長さ（秒）
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    /// 25時間表記での開始時刻表示
    var displayTime: String {
        TimeConverter.convertTo25HourFormat(startTime)
    }
    
    /// 出演者名の結合表示
    var personalitiesText: String {
        personalities.joined(separator: " / ")
    }
    
    /// 深夜番組かどうか（00:00-05:00の番組）
    var isLateNight: Bool {
        let hour = Calendar.current.component(.hour, from: startTime)
        return hour >= 0 && hour < 5
    }
}

// MARK: - Test Extensions
#if DEBUG
extension RadioProgram {
    /// テスト用朝番組
    static let mockMorningShow = RadioProgram(
        id: "prog_001",
        title: "モーニングテスト番組",
        description: "テスト用朝番組",
        startTime: Date().setTime(hour: 6, minute: 0),
        endTime: Date().setTime(hour: 9, minute: 0),
        personalities: ["テストパーソナリティA"],
        stationId: "TBS"
    )
    
    /// テスト用深夜番組
    static let mockLateNightShow = RadioProgram(
        id: "prog_002",
        title: "深夜テスト番組",
        description: "25時間表記テスト用",
        startTime: Date().setTime(hour: 1, minute: 0), // 実際の25:00
        endTime: Date().setTime(hour: 3, minute: 0),   // 実際の27:00
        personalities: ["テストパーソナリティB"],
        stationId: "TBS"
    )
    
    /// テスト用Session番組
    static let mockSessionShow = RadioProgram(
        id: "prog_003",
        title: "荻上チキ・Session",
        description: "平日22時から放送中",
        startTime: Date().setTime(hour: 22, minute: 0),
        endTime: Date().setTime(hour: 24, minute: 0),
        personalities: ["荻上チキ", "南部広美"],
        stationId: "TBS"
    )
    
    /// テスト用番組配列
    static let mockPrograms = [mockMorningShow, mockLateNightShow, mockSessionShow]
    
    /// 空の番組配列
    static let emptyPrograms: [RadioProgram] = []
}
#endif

// MARK: - Helper Classes
/// 時刻変換ユーティリティ（一時的な実装）
class TimeConverter {
    /// 25時間表記への変換
    static func convertTo25HourFormat(_ date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        // 深夜0-5時は24-29時表記に変換
        let displayHour = (hour >= 0 && hour < 5) ? hour + 24 : hour
        return String(format: "%02d:%02d", displayHour, minute)
    }
    
    /// 25時間表記から実時刻への変換
    static func convertFrom25HourFormat(_ timeString: String, baseDate: Date) -> Date {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return baseDate
        }
        
        let actualHour = hour >= 24 ? hour - 24 : hour
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: baseDate)
        dateComponents.hour = actualHour
        dateComponents.minute = minute
        
        return Calendar.current.date(from: dateComponents) ?? baseDate
    }
}

// MARK: - Date Extension
extension Date {
    /// 時刻設定ヘルパー
    func setTime(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: self)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components) ?? self
    }
}