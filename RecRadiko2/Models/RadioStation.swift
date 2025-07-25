//
//  RadioStation.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import Foundation

/// 放送局情報を表すモデル
struct RadioStation: Identifiable, Hashable, Codable {
    let id: String          // 放送局ID (例: "TBS")
    let name: String        // 放送局名 (例: "TBSラジオ")
    let displayName: String // 表示名 (例: "TBS")
    let logoURL: String?    // ロゴ画像URL
    let areaId: String      // 所属地域ID (例: "JP13")
    let bannerURL: String?  // バナー画像URL
    let href: String?       // 放送局WebサイトURL
    
    init(id: String, name: String, displayName: String, logoURL: String? = nil, areaId: String, bannerURL: String? = nil, href: String? = nil) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.logoURL = logoURL
        self.areaId = areaId
        self.bannerURL = bannerURL
        self.href = href
    }
}

// MARK: - Test Extensions
#if DEBUG
extension RadioStation {
    /// テスト用TBSラジオ
    static let mockTBS = RadioStation(
        id: "TBS",
        name: "TBSラジオ",
        displayName: "TBS",
        logoURL: "https://mock.example.com/tbs.png",
        areaId: "JP13"
    )
    
    /// テスト用文化放送
    static let mockQRR = RadioStation(
        id: "QRR",
        name: "文化放送",
        displayName: "QRR",
        logoURL: "https://mock.example.com/qrr.png",
        areaId: "JP13"
    )
    
    /// テスト用ニッポン放送
    static let mockLFR = RadioStation(
        id: "LFR",
        name: "ニッポン放送",
        displayName: "LFR",
        logoURL: "https://mock.example.com/lfr.png",
        areaId: "JP13"
    )
    
    /// テスト用放送局配列
    static let mockStations = [mockTBS, mockQRR, mockLFR]
    
    /// 空の放送局配列
    static let emptyStations: [RadioStation] = []
}
#endif