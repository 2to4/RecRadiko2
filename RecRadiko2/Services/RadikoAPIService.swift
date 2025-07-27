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
            // 認証確認（必要に応じて認証実行）
            _ = try await ensureAuthenticated()
            
            // 番組表XML取得
            let programListURL = RadikoAPIEndpoint.programListURL(stationId: stationId, date: date)
            guard let url = URL(string: programListURL) else {
                throw RadikoError.invalidResponse
            }
            
            let xmlResponse = try await httpClient.requestText(
                url,
                method: .get,
                headers: [:],
                body: nil
            )
            
            // XML解析
            guard let xmlData = xmlResponse.data(using: .utf8) else {
                throw RadikoError.parsingError("XML文字列をDataに変換できませんでした")
            }
            
            let programs = try xmlParser.parseProgramList(from: xmlData)
            
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

// MARK: - RadikoAPIServiceProtocol Compliance
extension RadikoAPIService: RadikoAPIServiceProtocol {
    // プロトコルメソッドは既に実装済み
}