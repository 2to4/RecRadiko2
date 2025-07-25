//
//  MemoryCacheService.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/26.
//

import Foundation
@testable import RecRadiko2

/// テスト用メモリベースキャッシュサービス
class MemoryCacheService: CacheServiceProtocol {
    private var cache: [String: (data: Data, expiresAt: Date)] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    func save<T: Codable>(_ object: T, for policy: CachePolicy) throws {
        let wrapper = CacheWrapper(
            data: object,
            expiresAt: Date().addingTimeInterval(policy.expiration)
        )
        
        let data = try encoder.encode(wrapper)
        let key = cacheKey(for: policy)
        cache[key] = (data: data, expiresAt: wrapper.expiresAt)
    }
    
    func load<T: Codable>(_ type: T.Type, for policy: CachePolicy) throws -> T? {
        let key = cacheKey(for: policy)
        guard let cached = cache[key] else {
            return nil
        }
        
        // 有効期限チェック
        guard cached.expiresAt > Date() else {
            cache.removeValue(forKey: key)
            return nil
        }
        
        do {
            let wrapper = try decoder.decode(CacheWrapper<T>.self, from: cached.data)
            
            // 再度有効期限チェック
            guard wrapper.expiresAt > Date() else {
                cache.removeValue(forKey: key)
                return nil
            }
            
            return wrapper.data
        } catch {
            // デコードに失敗した場合はキャッシュを削除
            cache.removeValue(forKey: key)
            throw CacheError.decodingFailed
        }
    }
    
    func invalidate(for policy: CachePolicy) {
        let key = cacheKey(for: policy)
        cache.removeValue(forKey: key)
    }
    
    func invalidateAll() {
        cache.removeAll()
    }
    
    func cacheInfo(for policy: CachePolicy) -> CacheInfo? {
        let key = cacheKey(for: policy)
        guard let cached = cache[key] else { return nil }
        
        let attributes: [FileAttributeKey: Any] = [
            .size: cached.data.count,
            .modificationDate: Date()
        ]
        
        return CacheInfo(
            policy: policy,
            fileAttributes: attributes,
            expiresAt: cached.expiresAt
        )
    }
    
    private func cacheKey(for policy: CachePolicy) -> String {
        return policy.key
    }
}

// MARK: - Test Helpers
extension MemoryCacheService {
    /// テスト用：キャッシュデータを直接設定
    func setCache<T: Codable>(_ object: T, for policy: CachePolicy, expiresAt: Date) throws {
        let wrapper = CacheWrapper(data: object, expiresAt: expiresAt)
        let data = try encoder.encode(wrapper)
        let key = cacheKey(for: policy)
        cache[key] = (data: data, expiresAt: expiresAt)
    }
    
    /// テスト用：破損したデータを設定
    func setCorruptedCache(for policy: CachePolicy) {
        let key = cacheKey(for: policy)
        let corruptedData = "corrupted".data(using: .utf8)!
        cache[key] = (data: corruptedData, expiresAt: Date().addingTimeInterval(3600))
    }
    
    /// テスト用：キャッシュの存在確認
    func hasCache(for policy: CachePolicy) -> Bool {
        let key = cacheKey(for: policy)
        return cache[key] != nil
    }
}