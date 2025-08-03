//
//  RadioProgram.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import Foundation

/// 番組情報を表すモデル
struct RadioProgram: Identifiable, Hashable, Codable {
    let programId: String       // 番組ID（Radiko APIから取得）
    let title: String           // 番組名
    let description: String     // 番組説明
    let startTime: Date         // 開始時刻
    let endTime: Date           // 終了時刻
    let personalities: [String] // 出演者リスト
    let stationId: String       // 所属放送局ID
    let imageURL: String?       // 番組画像URL
    let isTimeFree: Bool        // タイムフリー対応フラグ
    
    /// Identifiableプロトコルのid実装
    /// 番組IDと開始時刻を組み合わせて一意性を確保
    var id: String {
        return "\(programId)_\(Int(startTime.timeIntervalSince1970))"
    }
    
    init(id: String, title: String, description: String, startTime: Date, endTime: Date, personalities: [String], stationId: String, imageURL: String? = nil, isTimeFree: Bool = false) {
        self.programId = id
        self.title = title
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.personalities = personalities
        self.stationId = stationId
        self.imageURL = imageURL
        self.isTimeFree = isTimeFree
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
        TimeConverter.formatProgramTime(startTime)
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
    
    /// 深夜番組かどうか（テスト用エイリアス）
    var isMidnightProgram: Bool {
        isLateNight
    }
}

// MARK: - Test Extensions
#if DEBUG
extension RadioProgram {
    /// テスト用朝番組
    static let mockMorningShow: RadioProgram = {
        let calendar = Calendar.current
        let today = Date()
        let startTime = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: today) ?? today
        let endTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today) ?? today
        
        return RadioProgram(
            id: "prog_001",
            title: "モーニングテスト番組",
            description: "テスト用朝番組",
            startTime: startTime,
            endTime: endTime,
            personalities: ["テストパーソナリティA"],
            stationId: "TBS"
        )
    }()
    
    /// テスト用深夜番組
    static let mockLateNightShow: RadioProgram = {
        let calendar = Calendar.current
        let today = Date()
        let startTime = calendar.date(bySettingHour: 1, minute: 0, second: 0, of: today) ?? today // 実際の25:00
        let endTime = calendar.date(bySettingHour: 3, minute: 0, second: 0, of: today) ?? today   // 実際の27:00
        
        return RadioProgram(
            id: "prog_002",
            title: "深夜テスト番組",
            description: "25時間表記テスト用",
            startTime: startTime,
            endTime: endTime,
            personalities: ["テストパーソナリティB"],
            stationId: "TBS"
        )
    }()
    
    /// テスト用Session番組
    static let mockSessionShow: RadioProgram = {
        let calendar = Calendar.current
        let today = Date()
        let startTime = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: today) ?? today
        let endTime = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: today) ?? today) ?? today
        
        return RadioProgram(
            id: "prog_003",
            title: "荻上チキ・Session",
            description: "平日22時から放送中",
            startTime: startTime,
            endTime: endTime,
            personalities: ["荻上チキ", "南部広美"],
            stationId: "TBS"
        )
    }()
    
    /// テスト用番組配列
    static let mockPrograms = [mockMorningShow, mockLateNightShow, mockSessionShow]
    
    /// 空の番組配列
    static let emptyPrograms: [RadioProgram] = []
}
#endif

