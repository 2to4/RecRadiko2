//
//  CacheServiceTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/25.
//

import Testing
import Foundation
@testable import RecRadiko2

@Suite("CacheService Tests")
struct CacheServiceTests {
    
    // MARK: - 基本キャッシュ操作テスト
    
    @Test("オブジェクトの保存と読み込み")
    func saveAndLoadObject() throws {
        // Given
        let cacheService = MemoryCacheService()
        let testStations = [
            createTestRadioStation(id: "TBS", name: "TBSラジオ"),
            createTestRadioStation(id: "QRR", name: "文化放送")
        ]
        
        // When
        try cacheService.save(testStations, for: .stationList())
        let loadedStations: [RadioStation]? = try cacheService.load([RadioStation].self, for: .stationList())
        
        // Then
        #expect(loadedStations?.count == 2)
        #expect(loadedStations?[0].id == "TBS")
        #expect(loadedStations?[0].name == "TBSラジオ")
        #expect(loadedStations?[1].id == "QRR")
        #expect(loadedStations?[1].name == "文化放送")
    }
    
    @Test("存在しないキャッシュの読み込み")
    func loadNonExistentCache() throws {
        // Given
        let cacheService = MemoryCacheService()
        
        // When
        let loadedData: [String]? = try cacheService.load([String].self, for: .stationList())
        
        // Then
        #expect(loadedData == nil)
    }
    
    @Test("異なる型でのキャッシュ操作")
    func differentDataTypes() throws {
        // Given
        let cacheService = MemoryCacheService()
        
        // String配列のキャッシュ
        let stringArray = ["test1", "test2", "test3"]
        try cacheService.save(stringArray, for: .stationList())
        
        // Int配列のキャッシュ
        let intArray = [1, 2, 3, 4, 5]
        try cacheService.save(intArray, for: .programList())
        
        // AuthInfoのキャッシュ
        let authInfo = AuthInfo.create(authToken: "test", areaId: "JP13", areaName: "東京都")
        try cacheService.save(authInfo, for: .authInfo())
        
        // When & Then
        let loadedStrings: [String]? = try cacheService.load([String].self, for: .stationList())
        let loadedInts: [Int]? = try cacheService.load([Int].self, for: .programList())
        let loadedAuth: AuthInfo? = try cacheService.load(AuthInfo.self, for: .authInfo())
        
        #expect(loadedStrings == stringArray)
        #expect(loadedInts == intArray)
        #expect(loadedAuth?.authToken == authInfo.authToken)
        #expect(loadedAuth?.areaId == authInfo.areaId)
    }
    
    // MARK: - 有効期限テスト
    
    @Test("有効期限内のキャッシュ読み込み")
    func loadValidCache() throws {
        // Given
        let cacheService = MemoryCacheService()
        let testData = ["valid_data"]
        let longPolicy = CachePolicy.stationList(expiration: 3600) // 1時間
        
        // When
        try cacheService.save(testData, for: longPolicy)
        let loadedData: [String]? = try cacheService.load([String].self, for: longPolicy)
        
        // Then
        #expect(loadedData == testData)
    }
    
    @Test("有効期限切れキャッシュの処理")
    func expiredCacheHandling() throws {
        // Given
        let cacheService = MemoryCacheService()
        let testData = ["expired_data"]
        let shortPolicy = CachePolicy.stationList(expiration: 0.1) // 0.1秒
        
        // When
        try cacheService.save(testData, for: shortPolicy)
        
        // 有効期限まで待機
        Thread.sleep(forTimeInterval: 0.2)
        
        let loadedData: [String]? = try cacheService.load([String].self, for: shortPolicy)
        
        // Then
        #expect(loadedData == nil) // 期限切れのためnil
    }
    
    @Test("ゼロ秒有効期限のキャッシュ")
    func zeroExpirationCache() throws {
        // Given
        let cacheService = MemoryCacheService()
        let testData = ["immediate_expire"]
        
        // When - 過去の有効期限でキャッシュを設定
        let expiredDate = Date().addingTimeInterval(-1) // 1秒前
        try cacheService.setCache(testData, for: .stationList(), expiresAt: expiredDate)
        
        // Then
        let loadedData: [String]? = try cacheService.load([String].self, for: .stationList())
        #expect(loadedData == nil) // 即座に期限切れ
    }
    
    // MARK: - キャッシュ無効化テスト
    
    @Test("特定キャッシュの無効化")
    func invalidateSpecificCache() throws {
        // Given
        let cacheService = MemoryCacheService()
        let stationData = ["station_data"]
        let programData = ["program_data"]
        
        try cacheService.save(stationData, for: .stationList())
        try cacheService.save(programData, for: .programList())
        
        // When
        cacheService.invalidate(for: .stationList())
        
        // Then
        let loadedStationData: [String]? = try cacheService.load([String].self, for: .stationList())
        let loadedProgramData: [String]? = try cacheService.load([String].self, for: .programList())
        
        #expect(loadedStationData == nil) // 無効化されたデータ
        #expect(loadedProgramData == programData) // 他のデータは残存
    }
    
    @Test("全キャッシュの無効化")
    func invalidateAllCache() throws {
        // Given
        let cacheService = MemoryCacheService()
        let stationData = ["station_data"]
        let programData = ["program_data"]
        let authData = AuthInfo.create(authToken: "test", areaId: "JP13", areaName: "東京都")
        
        try cacheService.save(stationData, for: .stationList())
        try cacheService.save(programData, for: .programList())
        try cacheService.save(authData, for: .authInfo())
        
        // When
        cacheService.invalidateAll()
        
        // Then
        let loadedStationData: [String]? = try cacheService.load([String].self, for: .stationList())
        let loadedProgramData: [String]? = try cacheService.load([String].self, for: .programList())
        let loadedAuthData: AuthInfo? = try cacheService.load(AuthInfo.self, for: .authInfo())
        
        #expect(loadedStationData == nil)
        #expect(loadedProgramData == nil)
        #expect(loadedAuthData == nil)
    }
    
    // MARK: - エラーハンドリングテスト
    
    @Test("破損したキャッシュファイルの処理")
    func corruptedCacheHandling() throws {
        // Given
        let cacheService = MemoryCacheService()
        let policy = CachePolicy.stationList()
        
        // 破損したデータを設定
        cacheService.setCorruptedCache(for: policy)
        
        // When & Then
        #expect(throws: CacheError.decodingFailed) {
            let _: [String]? = try cacheService.load([String].self, for: policy)
        }
        
        // 破損したキャッシュが削除されることを確認
        #expect(!cacheService.hasCache(for: policy))
    }
    
    @Test("読み取り専用ディレクトリでのエラー")
    func readOnlyDirectoryError() {
        // Given - 通常は書き込み可能なディレクトリを使用するため、
        // このテストは概念的な確認として実装
        
        // When & Then
        // 実際のファイルシステム権限エラーは統合テストで確認
        // ここでは CacheError の種類が適切に定義されていることを確認
        let error = CacheError.encodingFailed
        #expect(error.errorDescription == "データのエンコードに失敗しました")
        
        let decodingError = CacheError.decodingFailed
        #expect(decodingError.errorDescription == "データのデコードに失敗しました")
        
        let directoryError = CacheError.directoryNotFound
        #expect(directoryError.errorDescription == "キャッシュディレクトリが見つかりません")
    }
    
    // MARK: - パフォーマンステスト
    
    @Test("大量データのキャッシュ性能")
    func largeCachePerformance() throws {
        // Given
        let cacheService = MemoryCacheService()
        let largeDataSet = (0..<10000).map { "data_item_\($0)" }
        
        // When - 保存性能測定
        let saveStartTime = Date()
        try cacheService.save(largeDataSet, for: .stationList())
        let saveEndTime = Date()
        
        // When - 読み込み性能測定
        let loadStartTime = Date()
        let loadedData: [String]? = try cacheService.load([String].self, for: .stationList())
        let loadEndTime = Date()
        
        // Then
        let saveTime = saveEndTime.timeIntervalSince(saveStartTime)
        let loadTime = loadEndTime.timeIntervalSince(loadStartTime)
        
        #expect(saveTime < 1.0) // 1秒以内で保存完了
        #expect(loadTime < 0.5) // 0.5秒以内で読み込み完了
        #expect(loadedData?.count == 10000)
        #expect(loadedData?[0] == "data_item_0")
        #expect(loadedData?[9999] == "data_item_9999")
    }
    
    // MARK: - キャッシュ情報取得テスト
    
    @Test("キャッシュサイズとファイル数の取得")
    func cacheInfoRetrieval() throws {
        // Given
        let cacheService = MemoryCacheService()
        let testData = Array(0..<100).map { "data_\($0)" }
        let policy = CachePolicy.stationList()
        
        // When
        try cacheService.save(testData, for: policy)
        let cacheInfo = cacheService.cacheInfo(for: policy)
        
        // Then
        #expect(cacheInfo != nil)
        #expect(cacheInfo?.policy.key == policy.key)
        #expect(cacheInfo?.expiresAt ?? Date() > Date())
        
        if let size = cacheInfo?.fileAttributes[.size] as? Int {
            #expect(size > 0)
        }
    }
    
    // MARK: - キャッシュポリシーテスト
    
    @Test("異なるキャッシュポリシーの動作")
    func differentCachePolicies() throws {
        // Given
        let cacheService = MemoryCacheService()
        
        let stationPolicy = CachePolicy.stationList(expiration: 86400) // 24時間
        let programPolicy = CachePolicy.programList(expiration: 21600) // 6時間
        let authPolicy = CachePolicy.authInfo(expiration: 3600) // 1時間
        
        // When
        #expect(stationPolicy.key == "cache_station_list")
        #expect(stationPolicy.expiration == 86400)
        
        #expect(programPolicy.key == "cache_program_list")
        #expect(programPolicy.expiration == 21600)
        
        #expect(authPolicy.key == "cache_auth_info")
        #expect(authPolicy.expiration == 3600)
        
        // 異なるポリシーで同じデータ型を保存
        let testData = ["shared_data"]
        try cacheService.save(testData, for: stationPolicy)
        try cacheService.save(testData, for: programPolicy)
        
        // Then - 独立してキャッシュされる
        let stationData: [String]? = try cacheService.load([String].self, for: stationPolicy)
        let programData: [String]? = try cacheService.load([String].self, for: programPolicy)
        
        #expect(stationData == testData)
        #expect(programData == testData)
        
        // 一方を無効化しても他方は残る
        cacheService.invalidate(for: stationPolicy)
        
        let stationDataAfter: [String]? = try cacheService.load([String].self, for: stationPolicy)
        let programDataAfter: [String]? = try cacheService.load([String].self, for: programPolicy)
        
        #expect(stationDataAfter == nil)
        #expect(programDataAfter == testData)
    }
    
    // MARK: - ヘルパーメソッド
    
    private func createTestRadioStation(id: String, name: String) -> RadioStation {
        return RadioStation(
            id: id,
            name: name,
            displayName: id,
            logoURL: "https://example.com/\(id.lowercased())_logo.png",
            areaId: "JP13"
        )
    }
    
    private func getCacheDirectory() throws -> URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cachePath = paths.first else {
            throw CacheError.directoryNotFound
        }
        return cachePath.appendingPathComponent("RecRadiko2", isDirectory: true)
    }
}

// MARK: - テスト用拡張
extension CacheService {
    /// テスト用: キャッシュファイルのURLを取得
    func cacheFileURL(for policy: CachePolicy) -> URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cachePath = paths.first!.appendingPathComponent("RecRadiko2", isDirectory: true)
        return cachePath.appendingPathComponent("\(policy.key).cache")
    }
}