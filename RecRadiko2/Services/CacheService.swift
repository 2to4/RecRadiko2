//
//  CacheService.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/25.
//

import Foundation

/// キャッシュポリシー定義
enum CachePolicy {
    case stationList(expiration: TimeInterval = 3600 * 24)     // 24時間
    case programList(expiration: TimeInterval = 3600 * 6)      // 6時間
    case authInfo(expiration: TimeInterval = 3600)             // 1時間
    
    var key: String {
        switch self {
        case .stationList:
            return "cache_station_list"
        case .programList:
            return "cache_program_list"
        case .authInfo:
            return "cache_auth_info"
        }
    }
    
    var expiration: TimeInterval {
        switch self {
        case .stationList(let exp):
            return exp
        case .programList(let exp):
            return exp
        case .authInfo(let exp):
            return exp
        }
    }
}

/// キャッシュサービスプロトコル
protocol CacheServiceProtocol {
    /// オブジェクトをキャッシュに保存
    /// - Parameters:
    ///   - object: 保存するオブジェクト
    ///   - policy: キャッシュポリシー
    func save<T: Codable>(_ object: T, for policy: CachePolicy) throws
    
    /// キャッシュからオブジェクトを読み込み
    /// - Parameters:
    ///   - type: 読み込むオブジェクトの型
    ///   - policy: キャッシュポリシー
    /// - Returns: キャッシュされたオブジェクト（有効期限内の場合）
    func load<T: Codable>(_ type: T.Type, for policy: CachePolicy) throws -> T?
    
    /// 指定したキャッシュを無効化
    /// - Parameter policy: キャッシュポリシー
    func invalidate(for policy: CachePolicy)
    
    /// 全キャッシュを無効化
    func invalidateAll()
}

/// キャッシュサービス実装
class CacheService: CacheServiceProtocol {
    // MARK: - Properties
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // MARK: - Initializer
    init() throws {
        // キャッシュディレクトリ作成
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cachePath = paths.first else {
            throw CacheError.directoryNotFound
        }
        
        cacheDirectory = cachePath.appendingPathComponent("RecRadiko2", isDirectory: true)
        
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try fileManager.createDirectory(at: cacheDirectory,
                                          withIntermediateDirectories: true)
        }
    }
    
    // MARK: - CacheServiceProtocol Implementation
    func save<T: Codable>(_ object: T, for policy: CachePolicy) throws {
        let wrapper = CacheWrapper(
            data: object,
            expiresAt: Date().addingTimeInterval(policy.expiration)
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(wrapper)
            let fileURL = cacheFileURL(for: policy)
            try data.write(to: fileURL)
        } catch {
            throw CacheError.encodingFailed
        }
    }
    
    func load<T: Codable>(_ type: T.Type, for policy: CachePolicy) throws -> T? {
        let fileURL = cacheFileURL(for: policy)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let wrapper = try decoder.decode(CacheWrapper<T>.self, from: data)
            
            // 有効期限チェック
            if wrapper.expiresAt < Date() {
                invalidate(for: policy)
                return nil
            }
            
            return wrapper.data
        } catch {
            // 破損したキャッシュファイルは削除
            invalidate(for: policy)
            throw CacheError.decodingFailed
        }
    }
    
    func invalidate(for policy: CachePolicy) {
        let fileURL = cacheFileURL(for: policy)
        try? fileManager.removeItem(at: fileURL)
    }
    
    func invalidateAll() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, 
                                                              includingPropertiesForKeys: nil)
            for fileURL in contents {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            // 全削除が失敗した場合はディレクトリごと削除・再作成
            try? fileManager.removeItem(at: cacheDirectory)
            try? fileManager.createDirectory(at: cacheDirectory,
                                           withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Private Methods
    private func cacheFileURL(for policy: CachePolicy) -> URL {
        return cacheDirectory.appendingPathComponent("\(policy.key).cache")
    }
}

// MARK: - Cache Wrapper
struct CacheWrapper<T: Codable>: Codable {
    let data: T
    let expiresAt: Date
}

// MARK: - Cache Error
enum CacheError: LocalizedError {
    case directoryNotFound
    case encodingFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .directoryNotFound:
            return "キャッシュディレクトリが見つかりません"
        case .encodingFailed:
            return "データのエンコードに失敗しました"
        case .decodingFailed:
            return "データのデコードに失敗しました"
        }
    }
}

// MARK: - Cache Info
struct CacheInfo {
    let policy: CachePolicy
    let fileAttributes: [FileAttributeKey: Any]
    let expiresAt: Date
}

// MARK: - Extensions
extension CacheService {
    /// キャッシュディレクトリのサイズを取得
    var cacheSize: Int64 {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory,
                                                              includingPropertiesForKeys: [.fileSizeKey])
            return contents.reduce(0) { total, url in
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                    return total + Int64(resourceValues.fileSize ?? 0)
                } catch {
                    return total
                }
            }
        } catch {
            return 0
        }
    }
    
    /// キャッシュディレクトリのファイル数を取得
    var cacheFileCount: Int {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory,
                                                              includingPropertiesForKeys: nil)
            return contents.count
        } catch {
            return 0
        }
    }
}