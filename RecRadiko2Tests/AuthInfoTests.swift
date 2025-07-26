//
//  AuthInfoTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/25.
//

import Testing
import Foundation
@testable import RecRadiko2

@Suite("AuthInfo Tests")
struct AuthInfoTests {
    
    // MARK: - 基本プロパティテスト
    
    @Test("AuthInfo初期化と基本プロパティ")
    func authInfoInitialization() {
        // Given
        let authToken = "test_auth_token"
        let areaId = "JP13"
        let areaName = "東京都"
        let expiresAt = Date().addingTimeInterval(3600) // 1時間後
        
        // When
        let authInfo = AuthInfo(
            authToken: authToken,
            areaId: areaId,
            areaName: areaName,
            expiresAt: expiresAt
        )
        
        // Then
        #expect(authInfo.authToken == authToken)
        #expect(authInfo.areaId == areaId)
        #expect(authInfo.areaName == areaName)
        #expect(authInfo.expiresAt == expiresAt)
    }
    
    @Test("有効性判定 - 有効な認証情報")
    func isValidWhenNotExpired() {
        // Given
        let authInfo = AuthInfo.create(
            authToken: "test_token",
            areaId: "JP13",
            areaName: "東京都"
        )
        
        // When & Then
        #expect(authInfo.isValid == true)
        #expect(authInfo.remainingTime > 0)
        #expect(authInfo.remainingMinutes > 0)
    }
    
    @Test("有効性判定 - 期限切れの認証情報")
    func isValidWhenExpired() {
        // Given
        let expiredTime = Date().addingTimeInterval(-3600) // 1時間前
        let authInfo = AuthInfo(
            authToken: "expired_token",
            areaId: "JP13",
            areaName: "東京都",
            expiresAt: expiredTime
        )
        
        // When & Then
        #expect(authInfo.isValid == false)
        #expect(authInfo.remainingTime == 0)
        #expect(authInfo.remainingMinutes == 0)
    }
    
    // MARK: - ファクトリーメソッドテスト
    
    @Test("create - デフォルト1時間有効")
    func createWithDefaultExpiration() {
        // Given
        let beforeCreation = Date()
        
        // When
        let authInfo = AuthInfo.create(
            authToken: "test_token",
            areaId: "JP13",
            areaName: "東京都"
        )
        
        _ = Date()
        
        // Then
        #expect(authInfo.isValid == true)
        
        // 有効期限が約1時間後であることを確認（多少の誤差を許容）
        let expectedExpiration = beforeCreation.addingTimeInterval(3600)
        let timeDifference = abs(authInfo.expiresAt.timeIntervalSince(expectedExpiration))
        #expect(timeDifference < 1.0) // 1秒以内の誤差
        
        // 残り時間が約1時間であることを確認
        #expect(authInfo.remainingMinutes >= 59)
        #expect(authInfo.remainingMinutes <= 60)
    }
    
    @Test("create - カスタム有効期限")
    func createWithCustomExpiration() {
        // Given
        let customValidTime: TimeInterval = 1800 // 30分
        
        // When
        let authInfo = AuthInfo.create(
            authToken: "test_token",
            areaId: "JP13",
            areaName: "東京都",
            validFor: customValidTime
        )
        
        // Then
        #expect(authInfo.isValid == true)
        #expect(authInfo.remainingMinutes >= 29)
        #expect(authInfo.remainingMinutes <= 30)
    }
    
    // MARK: - バリデーションテスト
    
    @Test("validate - 有効な認証情報")
    func validateValidAuthInfo() {
        // Given
        let authInfo = AuthInfo.create(
            authToken: "valid_token",
            areaId: "JP13",
            areaName: "東京都"
        )
        
        // When
        let result = authInfo.validate()
        
        // Then
        #expect(result == .valid)
        #expect(result.isUsable == true)
        #expect(result.message == nil)
    }
    
    @Test("validate - 期限切れの認証情報")
    func validateExpiredAuthInfo() {
        // Given
        let expiredAuthInfo = AuthInfo(
            authToken: "expired_token",
            areaId: "JP13",
            areaName: "東京都",
            expiresAt: Date().addingTimeInterval(-3600)
        )
        
        // When
        let result = expiredAuthInfo.validate()
        
        // Then
        #expect(result == .expired)
        #expect(result.isUsable == false)
        #expect(result.message == "認証の有効期限が切れています")
    }
    
    @Test("validate - 空の認証トークン")
    func validateEmptyAuthToken() {
        // Given
        let invalidAuthInfo = AuthInfo(
            authToken: "",
            areaId: "JP13",
            areaName: "東京都",
            expiresAt: Date().addingTimeInterval(3600)
        )
        
        // When
        let result = invalidAuthInfo.validate()
        
        // Then
        #expect(result == .invalid(reason: "認証トークンが空です"))
        #expect(result.isUsable == false)
        #expect(result.message == "認証トークンが空です")
    }
    
    @Test("validate - 空のエリアID")
    func validateEmptyAreaId() {
        // Given
        let invalidAuthInfo = AuthInfo(
            authToken: "valid_token",
            areaId: "",
            areaName: "東京都",
            expiresAt: Date().addingTimeInterval(3600)
        )
        
        // When
        let result = invalidAuthInfo.validate()
        
        // Then
        #expect(result == .invalid(reason: "エリアIDが空です"))
        #expect(result.isUsable == false)
    }
    
    @Test("validate - 有効期限が近い認証情報（警告）")
    func validateSoonToExpireAuthInfo() {
        // Given - 4分後に期限切れ（固定時刻で安定化）
        let baseTime = Date()
        let soonToExpireAuthInfo = AuthInfo(
            authToken: "valid_token",
            areaId: "JP13",
            areaName: "東京都",
            expiresAt: baseTime.addingTimeInterval(240) // 4分後
        )
        
        // When
        let result = soonToExpireAuthInfo.validate()
        
        // Then
        #expect(result.isUsable == true) // まだ使用可能
        switch result {
        case .warning(let reason):
            #expect(reason.contains("認証の有効期限が近づいています"))
            // 時間は実際の計算値を使用（4分または3分の可能性あり）
            #expect(reason.contains("分"))
        default:
            #expect(Bool(false), "Expected warning result, got: \(result)")
        }
    }
    
    // MARK: - Codableテスト
    
    @Test("JSON エンコード・デコード")
    func jsonEncodingDecoding() throws {
        // Given
        let originalAuthInfo = AuthInfo.create(
            authToken: "test_token",
            areaId: "JP13",
            areaName: "東京都"
        )
        
        // When - エンコード
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(originalAuthInfo)
        
        // When - デコード
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedAuthInfo = try decoder.decode(AuthInfo.self, from: jsonData)
        
        // Then
        #expect(decodedAuthInfo.authToken == originalAuthInfo.authToken)
        #expect(decodedAuthInfo.areaId == originalAuthInfo.areaId)
        #expect(decodedAuthInfo.areaName == originalAuthInfo.areaName)
        #expect(abs(decodedAuthInfo.expiresAt.timeIntervalSince(originalAuthInfo.expiresAt)) < 1.0)
    }
    
    // MARK: - Equatableテスト
    
    @Test("等価性テスト")
    func equality() {
        // Given
        let expiresAt = Date().addingTimeInterval(3600)
        
        let authInfo1 = AuthInfo(
            authToken: "token",
            areaId: "JP13",
            areaName: "東京都",
            expiresAt: expiresAt
        )
        
        let authInfo2 = AuthInfo(
            authToken: "token",
            areaId: "JP13",
            areaName: "東京都",
            expiresAt: expiresAt
        )
        
        let differentAuthInfo = AuthInfo(
            authToken: "different_token",
            areaId: "JP13",
            areaName: "東京都",
            expiresAt: expiresAt
        )
        
        // When & Then
        #expect(authInfo1 == authInfo2)
        #expect(authInfo1 != differentAuthInfo)
    }
    
    // MARK: - CustomStringConvertibleテスト
    
    @Test("文字列表現")
    func stringDescription() {
        // Given
        let authInfo = AuthInfo.create(
            authToken: "test_token",
            areaId: "JP13",
            areaName: "東京都"
        )
        
        // When
        let description = authInfo.description
        
        // Then
        #expect(description.contains("JP13"))
        #expect(description.contains("東京都"))
        #expect(description.contains("isValid: true"))
        #expect(description.contains("remainingMinutes:"))
    }
    
    // MARK: - エッジケーステスト
    
    @Test("残り時間の計算精度")
    func remainingTimeAccuracy() {
        // Given
        let exactExpiryTime = Date().addingTimeInterval(3665) // 1時間1分5秒後
        let authInfo = AuthInfo(
            authToken: "test_token",
            areaId: "JP13",
            areaName: "東京都",
            expiresAt: exactExpiryTime
        )
        
        // When & Then
        #expect(authInfo.remainingMinutes == 61) // 61分
        #expect(authInfo.remainingTime >= 3660) // 約3665秒
        #expect(authInfo.remainingTime <= 3670)
    }
    
    @Test("ValidationResult等価性")
    func validationResultEquality() {
        // When & Then
        #expect(AuthInfo.ValidationResult.valid == AuthInfo.ValidationResult.valid)
        #expect(AuthInfo.ValidationResult.expired == AuthInfo.ValidationResult.expired)
        #expect(
            AuthInfo.ValidationResult.warning(reason: "test") == 
            AuthInfo.ValidationResult.warning(reason: "test")
        )
        #expect(
            AuthInfo.ValidationResult.invalid(reason: "test") == 
            AuthInfo.ValidationResult.invalid(reason: "test")
        )
        
        // 異なる結果は等しくない
        #expect(AuthInfo.ValidationResult.valid != AuthInfo.ValidationResult.expired)
        #expect(
            AuthInfo.ValidationResult.warning(reason: "test1") != 
            AuthInfo.ValidationResult.warning(reason: "test2")
        )
    }
}