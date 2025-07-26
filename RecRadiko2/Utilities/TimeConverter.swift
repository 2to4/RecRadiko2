//
//  TimeConverter.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/25.
//

import Foundation

/// 時刻変換ユーティリティ
struct TimeConverter {
    
    // MARK: - Constants
    private static let radikoTimeZone = TimeZone(identifier: "Asia/Tokyo")!
    private static let radikoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.timeZone = radikoTimeZone
        return formatter
    }()
    
    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = radikoTimeZone
        return formatter
    }()
    
    // MARK: - Radiko Time Parsing
    
    /// Radiko時刻文字列（YYYYMMDDHHmmss）をDateに変換
    /// - Parameter timeString: Radiko形式の時刻文字列
    /// - Returns: 変換されたDate（失敗時はnil）
    static func parseRadikoTime(_ timeString: String) -> Date? {
        // 基本的な形式チェック
        guard timeString.count == 14,
              timeString.allSatisfy({ $0.isNumber }) else {
            return nil
        }
        
        // DateFormatterで解析
        guard let date = radikoDateFormatter.date(from: timeString) else {
            return nil
        }
        
        // 解析結果が元の文字列と一致することを確認（無効な日付の自動修正を防ぐ）
        let formattedBack = radikoDateFormatter.string(from: date)
        guard formattedBack == timeString else {
            return nil
        }
        
        return date
    }
    
    /// DateをRadiko時刻文字列に変換
    /// - Parameter date: 変換するDate
    /// - Returns: Radiko形式の時刻文字列
    static func formatRadikoTime(_ date: Date) -> String {
        return radikoDateFormatter.string(from: date)
    }
    
    // MARK: - 25-Hour Display Format
    
    /// 25時間表記用の時刻フォーマット
    /// - Parameter date: 表示するDate
    /// - Returns: 25時間表記の時刻文字列（HH:mm形式）
    static func formatProgramTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        guard let hour = components.hour, let minute = components.minute else {
            return "--:--"
        }
        
        // 深夜番組の25時間表記変換（0-4時を24-28時として表示）
        if hour < 5 {
            return String(format: "%02d:%02d", hour + 24, minute)
        } else {
            return String(format: "%02d:%02d", hour, minute)
        }
    }
    
    /// 番組の継続時間を文字列で表示
    /// - Parameter duration: 継続時間（秒）
    /// - Returns: 継続時間の表示文字列
    static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)時間\(remainingMinutes)分"
        } else {
            return "\(remainingMinutes)分"
        }
    }
    
    // MARK: - Broadcast Date Handling
    
    /// 番組の実際の放送日を取得（深夜番組考慮）
    /// - Parameter program: 番組情報
    /// - Returns: 放送日（深夜番組は前日扱い）
    static func getProgramDate(_ program: RadioProgram) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: program.startTime)
        
        if hour < 5 {
            // 深夜番組（0-4時）は前日扱い
            return calendar.date(byAdding: .day, value: -1, to: program.startTime) ?? program.startTime
        } else {
            return program.startTime
        }
    }
    
    /// 指定日の番組かどうか判定（深夜番組考慮）
    /// - Parameters:
    ///   - program: 判定する番組
    ///   - date: 対象日
    /// - Returns: 指定日の番組かどうか
    static func isProgramOnDate(_ program: RadioProgram, date: Date) -> Bool {
        let programDate = getProgramDate(program)
        let calendar = Calendar.current
        return calendar.isDate(programDate, inSameDayAs: date)
    }
    
    /// 放送日を表示用文字列に変換
    /// - Parameter date: 放送日
    /// - Returns: 表示用日付文字列（M/d(E)形式）
    static func formatProgramDate(_ date: Date) -> String {
        return displayDateFormatter.string(from: date)
    }
    
    // MARK: - Date Range Generation
    
    /// 番組表用の日付範囲を生成（過去1週間）
    /// - Returns: 過去1週間の日付配列（新しい順）
    static func generatePastWeekDates() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }.map { date in
            // 5時基準の放送日に調整
            date.broadcastDate
        }
    }
    
    /// 指定日の番組表取得範囲を計算
    /// - Parameter date: 対象日
    /// - Returns: 番組表取得範囲（5時から翌日5時まで）
    static func getProgramRange(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // 5時から翌日5時までの範囲
        let rangeStart = calendar.date(byAdding: .hour, value: 5, to: startOfDay)!
        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: rangeStart)!
        
        return (start: rangeStart, end: rangeEnd)
    }
    
    // MARK: - Time Validation
    
    /// 時刻文字列の妥当性チェック
    /// - Parameter timeString: チェックする時刻文字列
    /// - Returns: 妥当性（true: 有効, false: 無効）
    static func isValidRadikoTimeString(_ timeString: String) -> Bool {
        guard timeString.count == 14 else { return false }
        guard timeString.allSatisfy({ $0.isNumber }) else { return false }
        return parseRadikoTime(timeString) != nil
    }
    
    /// 番組時間の重複チェック
    /// - Parameters:
    ///   - program1: 番組1
    ///   - program2: 番組2
    /// - Returns: 重複しているかどうか
    static func isTimeOverlapping(_ program1: RadioProgram, _ program2: RadioProgram) -> Bool {
        return program1.startTime < program2.endTime && program2.startTime < program1.endTime
    }
}

// MARK: - Date Extension
extension Date {
    /// 5時を基準とした放送日を取得
    var broadcastDate: Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        
        if hour < 5 {
            // 0-4時は前日の放送日
            return calendar.date(byAdding: .day, value: -1, to: self) ?? self
        } else {
            return self
        }
    }
    
    /// 指定時間を加算（時間単位）
    /// - Parameter hours: 加算する時間数
    /// - Returns: 時間を加算したDate
    func addingHours(_ hours: Int) -> Date {
        return Calendar.current.date(byAdding: .hour, value: hours, to: self) ?? self
    }
    
    /// 指定分を加算（分単位）
    /// - Parameter minutes: 加算する分数
    /// - Returns: 分を加算したDate
    func addingMinutes(_ minutes: Int) -> Date {
        return Calendar.current.date(byAdding: .minute, value: minutes, to: self) ?? self
    }
    
    /// 日本時間での時刻コンポーネントを取得
    var japanTimeComponents: DateComponents {
        let calendar = Calendar.current
        return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: self)
    }
    
    /// 深夜番組かどうかを判定
    var isMidnightHour: Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        return hour >= 0 && hour < 5
    }
}

// MARK: - Calendar Extension
extension Calendar {
    /// 日本のカレンダーインスタンス
    static let japan: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }()
}