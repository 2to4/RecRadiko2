//
//  StationCell.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import SwiftUI

/// 放送局セルコンポーネント
struct StationCell: View {
    // MARK: - Properties
    let station: RadioStation
    let onTap: () -> Void
    
    // MARK: - State
    @State private var isHovered: Bool = false
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 8) {
            // ロゴ画像
            logoImage
            
            // 放送局名
            stationName
        }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .accessibilityLabel("\(station.name)放送局")
        .accessibilityHint("タップして番組一覧を表示")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Subviews
    /// ロゴ画像
    private var logoImage: some View {
        Group {
            if let logoURL = station.logoURL {
                AsyncImage(url: URL(string: logoURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    // ローディング中のプレースホルダー
                    ProgressView()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.appSecondaryText)
                }
            } else {
                // ロゴがない場合のデフォルト画像
                Image(systemName: "radio")
                    .font(.title)
                    .foregroundColor(.appSecondaryText)
            }
        }
        .frame(width: 120, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.appUIBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }
    
    /// 放送局名
    private var stationName: some View {
        Text(station.name)
            .font(.appCaption)
            .foregroundColor(.appPrimaryText)
            .lineLimit(1)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            StationCell(station: .mockTBS) {
                print("TBS selected")
            }
            
            StationCell(station: .mockQRR) {
                print("QRR selected")
            }
            
            StationCell(station: .mockLFR) {
                print("LFR selected")
            }
        }
        
        // ロゴURLなしのテスト
        StationCell(station: RadioStation(
            id: "TEST",
            name: "テスト放送局",
            displayName: "TEST",
            logoURL: nil,
            areaId: "JP13"
        )) {
            print("Test station selected")
        }
    }
    .padding()
    .background(Color.appBackground)
}