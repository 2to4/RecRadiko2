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
    init(httpClient: HTTPClientProtocol = HTTPClient(), 
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
            // 認証確認（必要に応じて認証実行）
            _ = try await ensureAuthenticated()
            
            // 放送局リストXML取得
            let stationListURL = RadikoAPIEndpoint.stationListURL(for: areaId)
            guard let url = URL(string: stationListURL) else {
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
            
            let stations = try xmlParser.parseStationList(from: xmlData)
            
            // データ検証
            let validationResult = xmlParser.validateStations(stations)
            if !validationResult.isValid {
                throw RadikoError.parsingError(validationResult.message ?? "放送局データの検証に失敗しました")
            }
            
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
        if await authSvc.isAuthenticated() {
            return await authSvc.currentAuthInfo!
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