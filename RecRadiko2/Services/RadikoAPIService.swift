//
//  RadikoAPIService.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/26.
//

import Foundation
import Combine

/// Radiko API統合サービス実装
class RadikoAPIService {
    
    // MARK: - Properties
    
    private let httpClient: HTTPClientProtocol
    private let xmlParser: RadikoXMLParser
    private var authService: AuthServiceProtocol?
    private let userDefaults: UserDefaultsProtocol
    
    // MARK: - Initializer
    
    /// 初期化メソッド
    init(httpClient: HTTPClientProtocol = RealHTTPClient(), 
         authService: AuthServiceProtocol? = nil,
         userDefaults: UserDefaultsProtocol = UserDefaults.standard) {
        self.httpClient = httpClient
        self.xmlParser = RadikoXMLParser()
        self.authService = authService
        self.userDefaults = userDefaults
    }
    
    // MARK: - RadikoAPIServiceProtocol Implementation
    
    func fetchStations(for areaId: String) async throws -> [RadioStation] {
        do {
            print("🔍 [RadikoAPIService] 放送局取得開始: エリア \(areaId)")
            
            // 認証確認（必要に応じて認証実行）
            let authInfo = try await ensureAuthenticated()
            print("✅ [RadikoAPIService] 認証完了: \(authInfo.areaId) - \(authInfo.areaName)")
            
            // 放送局リストXML取得
            let stationListURL = RadikoAPIEndpoint.stationListURL(for: areaId)
            guard let url = URL(string: stationListURL) else {
                throw RadikoError.invalidResponse
            }
            print("🌐 [RadikoAPIService] リクエストURL: \(url)")
            
            let xmlResponse = try await httpClient.requestText(
                url,
                method: .get,
                headers: [:],
                body: nil
            )
            print("📥 [RadikoAPIService] XMLレスポンス取得完了 (文字数: \(xmlResponse.count))")
            print("📄 [RadikoAPIService] XMLレスポンス（最初の500文字）: \(xmlResponse.prefix(500))")
            
            // XML解析
            guard let xmlData = xmlResponse.data(using: .utf8) else {
                throw RadikoError.parsingError("XML文字列をDataに変換できませんでした")
            }
            
            let stations = try xmlParser.parseStationList(from: xmlData)
            print("🎯 [RadikoAPIService] パース完了: \(stations.count)件の放送局")
            
            for (index, station) in stations.prefix(3).enumerated() {
                print("📻 [RadikoAPIService] [\(index+1)] \(station.name) (\(station.id)) - ロゴ: \(station.logoURL ?? "なし")")
            }
            
            // データ検証
            let validationResult = xmlParser.validateStations(stations)
            if !validationResult.isValid {
                print("❌ [RadikoAPIService] 検証失敗: \(validationResult.message ?? "不明なエラー")")
                throw RadikoError.parsingError(validationResult.message ?? "放送局データの検証に失敗しました")
            }
            print("✅ [RadikoAPIService] データ検証完了")
            
            return stations
            
        } catch let error as RadikoError {
            throw error
        } catch let error as ParsingError {
            throw RadikoError.parsingError(error.localizedDescription)
        } catch let error as HTTPError {
            throw RadikoError.networkError(error)
        } catch {
            throw RadikoError.networkError(error)
        }
    }
    
    func fetchPrograms(stationId: String, date: Date) async throws -> [RadioProgram] {
        do {
            print("📊 [RadikoAPIService] 番組取得開始 - 放送局ID: \(stationId), 日付: \(date)")
            
            // 認証確認（必要に応じて認証実行）
            let authInfo = try await ensureAuthenticated()
            print("✅ [RadikoAPIService] 認証完了 - エリア: \(authInfo.areaId)")
            
            // 番組表XML取得
            let programListURL = RadikoAPIEndpoint.programListURL(areaId: authInfo.areaId, date: date)
            guard let url = URL(string: programListURL) else {
                throw RadikoError.invalidResponse
            }
            print("🌐 [RadikoAPIService] 番組表URL: \(url)")
            
            let xmlResponse = try await httpClient.requestText(
                url,
                method: .get,
                headers: [:],
                body: nil
            )
            print("📥 [RadikoAPIService] XMLレスポンス取得完了 (文字数: \(xmlResponse.count))")
            print("📄 [RadikoAPIService] XMLレスポンス（最初の500文字）: \(xmlResponse.prefix(500))")
            
            // XML解析
            guard let xmlData = xmlResponse.data(using: .utf8) else {
                throw RadikoError.parsingError("XML文字列をDataに変換できませんでした")
            }
            
            let allPrograms = try xmlParser.parseProgramList(from: xmlData)
            print("🔍 [RadikoAPIService] 全番組数: \(allPrograms.count)")
            
            // **詳細デバッグ: 全stationIDを確認**
            let allStationIds = Set(allPrograms.map { $0.stationId })
            print("🏢 [RadikoAPIService] 発見されたstationID一覧: \(allStationIds.sorted())")
            
            // **詳細デバッグ: 指定stationIDの完全一致確認**
            let exactMatches = allPrograms.filter { $0.stationId == stationId }
            let partialMatches = allPrograms.filter { $0.stationId.contains(stationId) || stationId.contains($0.stationId) }
            print("✅ [RadikoAPIService] 完全一致: \(exactMatches.count)件, 部分一致: \(partialMatches.count)件")
            
            // 指定された放送局の番組のみをフィルタリング
            let filteredPrograms = exactMatches
            print("✨ [RadikoAPIService] フィルタ後の番組数: \(filteredPrograms.count) (放送局ID: \(stationId))")
            
            // **詳細デバッグ: 時間範囲の確認**
            if !filteredPrograms.isEmpty {
                let sortedByTime = filteredPrograms.sorted { $0.startTime < $1.startTime }
                let firstProgram = sortedByTime.first!
                let lastProgram = sortedByTime.last!
                print("⏰ [RadikoAPIService] 時間範囲: \(DateFormatter.timeLogFormatter.string(from: firstProgram.startTime)) - \(DateFormatter.timeLogFormatter.string(from: lastProgram.endTime))")
                
                // **欠損時間帯の詳細調査**
                for i in 0..<sortedByTime.count-1 {
                    let current = sortedByTime[i]
                    let next = sortedByTime[i+1]
                    let gap = next.startTime.timeIntervalSince(current.endTime)
                    if gap > 300 { // 5分以上の空白
                        let gapHours = Int(gap / 3600)
                        let gapMinutes = Int((gap.truncatingRemainder(dividingBy: 3600)) / 60)
                        print("🚨 [RadikoAPIService] 大きな空白発見: \(DateFormatter.timeLogFormatter.string(from: current.endTime)) - \(DateFormatter.timeLogFormatter.string(from: next.startTime)) (\(gapHours)時間\(gapMinutes)分)")
                        
                        // **この時間帯に他のstationIDで番組があるかチェック**
                        let gapStart = current.endTime
                        let gapEnd = next.startTime
                        let programsInGap = allPrograms.filter { program in
                            return program.startTime >= gapStart && program.startTime < gapEnd
                        }
                        
                        if !programsInGap.isEmpty {
                            let gapStationIds = Set(programsInGap.map { $0.stationId })
                            print("🔍 [RadikoAPIService] 空白時間帯の他station番組: \(programsInGap.count)件, stationID: \(gapStationIds.sorted())")
                            
                            // 最初のいくつかを詳細表示
                            for (index, program) in programsInGap.prefix(3).enumerated() {
                                print("    [\(index+1)] \(DateFormatter.timeLogFormatter.string(from: program.startTime)) \(program.stationId): \(program.title)")
                            }
                        }
                    }
                }
            }
            
            // フィルタリング後に再度時間順ソート（重要！）
            let programs = filteredPrograms.sorted { $0.startTime < $1.startTime }
            print("🔄 [RadikoAPIService] 時間順ソート完了")
            
            // 番組の連続性をチェック（詳細ログ）
            for i in 0..<programs.count-1 {
                let current = programs[i]
                let next = programs[i+1]
                let gap = next.startTime.timeIntervalSince(current.endTime)
                let gapMinutes = Int(gap / 60)
                
                if gap > 0 {
                    print("⏰ [RadikoAPIService] 番組間隔: \(current.title)(\(DateFormatter.timeLogFormatter.string(from: current.endTime))) -> \(next.title)(\(DateFormatter.timeLogFormatter.string(from: next.startTime))): \(gapMinutes)分")
                } else if gap < 0 {
                    print("⚠️ [RadikoAPIService] 番組重複: \(current.title) と \(next.title): \(abs(gapMinutes))分重複")
                }
            }
            
            // データ検証
            let validationResult = xmlParser.validatePrograms(programs)
            if !validationResult.isValid {
                throw RadikoError.parsingError(validationResult.message ?? "番組データの検証に失敗しました")
            }
            
            return programs
            
        } catch let error as RadikoError {
            throw error
        } catch let error as ParsingError {
            throw RadikoError.parsingError(error.localizedDescription)
        } catch let error as HTTPError {
            throw RadikoError.networkError(error)
        } catch {
            throw RadikoError.networkError(error)
        }
    }
    
    // MARK: - Additional Methods
    
    /// 番組表取得（オプション日付対応）
    /// - Parameters:
    ///   - stationId: 放送局ID
    ///   - date: 対象日（省略時は当日）
    /// - Returns: 番組配列
    func fetchProgramSchedule(stationId: String, date: Date?) async throws -> [RadioProgram] {
        return try await fetchPrograms(stationId: stationId, date: date ?? Date())
    }
    
    /// 認証情報取得
    /// - Returns: 認証情報
    func authenticate() async throws -> AuthInfo {
        let authSvc = try await getOrCreateAuthService()
        return try await authSvc.authenticate()
    }
    
    // MARK: - Private Methods
    
    /// 認証状態を確認し、必要に応じて認証を実行
    /// - Returns: 認証情報
    private func ensureAuthenticated() async throws -> AuthInfo {
        let authSvc = try await getOrCreateAuthService()
        if authSvc.isAuthenticated() {
            return authSvc.currentAuthInfo!
        } else {
            return try await authSvc.authenticate()
        }
    }
    
    /// 認証サービスを取得または作成
    /// - Returns: 認証サービス
    private func getOrCreateAuthService() async throws -> AuthServiceProtocol {
        if let authSvc = authService {
            return authSvc
        } else {
            let authSvc = RadikoAuthService(httpClient: httpClient, userDefaults: userDefaults)
            self.authService = authSvc
            return authSvc
        }
    }
}

// MARK: - DateFormatter Extension for Logging
extension DateFormatter {
    static let timeLogFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

// MARK: - RadikoAPIServiceProtocol Compliance
extension RadikoAPIService: RadikoAPIServiceProtocol {
    // プロトコルメソッドは既に実装済み
}