//
//  CustomTabBar.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import SwiftUI

/// カスタムタブバーコンポーネント
struct CustomTabBar: View {
    // MARK: - Types
    enum TabItem: String, CaseIterable {
        case stationList = "ラジオ局を選ぶ"
        case program = "ラジオ局"
        case settings = "設定"
        
        var identifier: String {
            switch self {
            case .stationList: return "station_list"
            case .program: return "program"
            case .settings: return "settings"
            }
        }
    }
    
    // MARK: - Properties
    @Binding var selectedTab: TabItem
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .frame(height: 40)
        .background(Color.appUIBackground)
    }
    
    // MARK: - Subviews
    /// タブボタン
    private func tabButton(for tab: TabItem) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            Text(tab.rawValue)
                .font(.appBody)
                .foregroundColor(selectedTab == tab ? .appPrimaryText : .appSecondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    selectedTab == tab 
                        ? Color.appSelectedBackground 
                        : Color.clear
                )
        }
        .buttonStyle(.plain) // デフォルトのボタンスタイルを無効化
        .accessibilityLabel(tab.rawValue)
        .accessibilityHint("タップして\(tab.rawValue)画面に移動")
        .accessibilityAddTraits(selectedTab == tab ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 0) {
        CustomTabBar(selectedTab: .constant(.stationList))
        
        Divider()
        
        // 異なる選択状態のテスト
        CustomTabBar(selectedTab: .constant(.program))
        
        Divider()
        
        CustomTabBar(selectedTab: .constant(.settings))
        
        Spacer()
    }
    .background(Color.appBackground)
}