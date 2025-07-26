//
//  UserDefaultsProtocol.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/26.
//

import Foundation

/// UserDefaults抽象化プロトコル
protocol UserDefaultsProtocol {
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
    func synchronize() -> Bool
}

/// 標準UserDefaults実装
extension UserDefaults: UserDefaultsProtocol {}

/// テスト専用UserDefaults実装
class TestUserDefaults: UserDefaultsProtocol {
    private var storage: [String: Any] = [:]
    
    func data(forKey key: String) -> Data? {
        return storage[key] as? Data
    }
    
    func set(_ value: Any?, forKey key: String) {
        storage[key] = value
    }
    
    func removeObject(forKey key: String) {
        storage.removeValue(forKey: key)
    }
    
    func synchronize() -> Bool {
        return true
    }
    
    func clear() {
        storage.removeAll()
    }
}