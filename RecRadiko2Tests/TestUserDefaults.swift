//
//  TestUserDefaults.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/26.
//

import Foundation
@testable import RecRadiko2

/// テスト専用UserDefaults実装
class TestUserDefaults: UserDefaultsProtocol {
    private var storage: [String: Any] = [:]
    
    func object(forKey defaultName: String) -> Any? {
        return storage[defaultName]
    }
    
    func data(forKey defaultName: String) -> Data? {
        return storage[defaultName] as? Data
    }
    
    func string(forKey defaultName: String) -> String? {
        return storage[defaultName] as? String
    }
    
    func integer(forKey defaultName: String) -> Int {
        return storage[defaultName] as? Int ?? 0
    }
    
    func bool(forKey defaultName: String) -> Bool {
        return storage[defaultName] as? Bool ?? false
    }
    
    func double(forKey defaultName: String) -> Double {
        return storage[defaultName] as? Double ?? 0.0
    }
    
    func float(forKey defaultName: String) -> Float {
        return storage[defaultName] as? Float ?? 0.0
    }
    
    func array(forKey defaultName: String) -> [Any]? {
        return storage[defaultName] as? [Any]
    }
    
    func dictionary(forKey defaultName: String) -> [String: Any]? {
        return storage[defaultName] as? [String: Any]
    }
    
    func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }
    
    func set(_ value: Int, forKey defaultName: String) {
        storage[defaultName] = value
    }
    
    func set(_ value: Bool, forKey defaultName: String) {
        storage[defaultName] = value
    }
    
    func set(_ value: Double, forKey defaultName: String) {
        storage[defaultName] = value
    }
    
    func set(_ value: Float, forKey defaultName: String) {
        storage[defaultName] = value
    }
    
    func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
    
    func synchronize() -> Bool {
        return true
    }
    
    /// テスト専用：ストレージをクリア
    func clear() {
        storage.removeAll()
    }
}