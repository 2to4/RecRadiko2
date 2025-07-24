//
//  Area.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import Foundation

/// 地域情報を表すモデル
struct Area: Identifiable, Hashable, Codable {
    let id: String      // 地域ID (例: "JP13")
    let name: String    // 地域名 (例: "東京")
    let displayName: String // 表示名 (例: "東京")
    
    init(id: String, name: String, displayName: String) {
        self.id = id
        self.name = name
        self.displayName = displayName
    }
}

// MARK: - 定数定義
extension Area {
    /// 東京地域
    static let tokyo = Area(id: "JP13", name: "東京", displayName: "東京")
    
    /// 神奈川地域
    static let kanagawa = Area(id: "JP14", name: "神奈川", displayName: "神奈川")
    
    /// 大阪地域
    static let osaka = Area(id: "JP27", name: "大阪", displayName: "大阪")
    
    /// 利用可能地域一覧
    static let allCases: [Area] = [tokyo, kanagawa, osaka]
}

// MARK: - Test Extensions
#if DEBUG
extension Area {
    /// テスト用東京地域
    static let mockTokyo = Area(id: "JP13", name: "東京", displayName: "東京")
    
    /// テスト用神奈川地域
    static let mockKanagawa = Area(id: "JP14", name: "神奈川", displayName: "神奈川")
    
    /// テスト用地域配列
    static let mockAreas = [mockTokyo, mockKanagawa]
}
#endif