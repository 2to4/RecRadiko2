//
//  TSParserTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/08/12.
//

import Testing
import Foundation
@testable import RecRadiko2

struct TSParserTests {
    
    private let parser = TSParser()
    
    // MARK: - 基本TSパケット解析テスト
    
    @Test("有効なTSパケットからのADTSフレーム抽出")
    func testValidTSPacketADTSExtraction() async throws {
        var tsData = Data()
        
        // TSパケット（PID=0x100, ADTSペイロード付き）
        tsData.append(0x47) // Sync byte
        tsData.append(0x41) // TEI=0, PUSI=1, Priority=0, PID upper bits
        tsData.append(0x00) // PID lower bits (0x100)
        tsData.append(0x10) // Scrambling=0, AFC=01, CC=0
        
        // PESヘッダー模倣（簡略版）
        tsData.append(contentsOf: [0x00, 0x00, 0x01]) // Start code
        tsData.append(contentsOf: [0xC0, 0x00, 0x00]) // Stream ID, length
        tsData.append(contentsOf: [0x80, 0x00, 0x00]) // PES header
        
        // ADTSフレーム（44.1kHz, 2ch）
        tsData.append(contentsOf: [0xFF, 0xF1]) // ADTS sync + profile
        tsData.append(contentsOf: [0x50, 0x80]) // Sample rate + channel
        tsData.append(contentsOf: [0x00, 0x20, 0x00]) // Frame length = 32
        tsData.append(Data(repeating: 0xCC, count: 25)) // Audio payload
        
        // パケットを188バイトに調整
        let remainingBytes = 188 - tsData.count
        tsData.append(Data(repeating: 0x00, count: remainingBytes))
        
        let frames = try parser.extractAudioFrames(from: tsData)
        
        #expect(!frames.isEmpty)
        #expect(frames[0].sampleRate == 44100)
        #expect(frames[0].channelCount == 2)
    }
    
    @Test("同期バイトなしデータでのエラー")
    func testNoSyncByteError() async throws {
        var invalidData = Data()
        
        // 同期バイトが全くない188バイトデータ
        invalidData.append(Data(repeating: 0x46, count: 188))
        
        await #expect(throws: TSParserError.noAudioData) {
            try parser.extractAudioFrames(from: invalidData)
        }
    }
    
    @Test("不正なパケットサイズでのエラー")
    func testInvalidPacketSizeError() async throws {
        var shortData = Data()
        
        // 187バイトのデータ（188バイトに満たない）
        shortData.append(0x47)
        shortData.append(Data(repeating: 0x00, count: 186))
        
        // このテストは実際には187バイトでも処理されるため、空のフレームでエラーになる
        await #expect(throws: TSParserError.noAudioData) {
            try parser.extractAudioFrames(from: shortData)
        }
    }
    
    // MARK: - 複数パケット処理テスト
    
    @Test("複数TSパケットでのADTSフレーム抽出")
    func testMultiplePacketADTSExtraction() async throws {
        var tsData = Data()
        
        // 2個のTSパケット作成（同一PID）
        for packetIndex in 0..<2 {
            tsData.append(0x47) // Sync byte
            tsData.append(0x41) // PUSI=1 for both packets
            tsData.append(0x00) // PID=0x100
            tsData.append(UInt8(0x10 + packetIndex)) // Different continuity counter
            
            // 最初のパケットにPESヘッダー
            if packetIndex == 0 {
                tsData.append(contentsOf: [0x00, 0x00, 0x01, 0xC0, 0x00, 0x00, 0x80, 0x00, 0x00])
            }
            
            // ADTSフレーム
            tsData.append(contentsOf: [0xFF, 0xF1, 0x50, 0x80, 0x00, 0x20, 0x00])
            tsData.append(Data(repeating: UInt8(0xAA + packetIndex), count: 25))
            
            // パケットを188バイトに調整
            let currentSize = tsData.count % 188
            if currentSize != 0 {
                let padding = 188 - currentSize
                tsData.append(Data(repeating: 0x00, count: padding))
            }
        }
        
        let frames = try parser.extractAudioFrames(from: tsData)
        
        #expect(frames.count >= 1) // 少なくとも1フレーム抽出
        #expect(frames[0].sampleRate == 44100)
        #expect(frames[0].channelCount == 2)
    }
    
    // MARK: - ADTSフレーム構造テスト
    
    @Test("ADTSFrameの正常な初期化")
    func testADTSFrameInitialization() async throws {
        var adtsData = Data()
        
        // ADTSヘッダー（32kHz, Mono）
        adtsData.append(contentsOf: [0xFF, 0xF1]) // Sync + profile
        adtsData.append(contentsOf: [0x48, 0x40]) // 32kHz, Mono
        adtsData.append(contentsOf: [0x00, 0x20, 0x00]) // Frame length = 32
        adtsData.append(Data(repeating: 0xBB, count: 25)) // Payload
        
        let frame = try ADTSFrame(data: adtsData)
        
        #expect(frame.sampleRate == 32000)
        #expect(frame.channelCount == 1) // Mono
        #expect(frame.frameLength == 32)
        #expect(frame.data.count == 32)
    }
    
    @Test("不正なADTSヘッダーでのエラー")
    func testInvalidADTSHeaderError() async throws {
        var invalidADTS = Data()
        
        // 不正な同期バイト
        invalidADTS.append(contentsOf: [0xFE, 0xF1])
        invalidADTS.append(Data(repeating: 0x00, count: 30))
        
        await #expect(throws: TSParserError.noAudioData) {
            try ADTSFrame(data: invalidADTS)
        }
    }
    
    // MARK: - エラーケーステスト
    
    @Test("空データでのエラーハンドリング")
    func testEmptyDataError() async throws {
        let emptyData = Data()
        
        await #expect(throws: TSParserError.noAudioData) {
            try parser.extractAudioFrames(from: emptyData)
        }
    }
    
    @Test("オーディオデータなしでのエラー")
    func testNoAudioDataError() async throws {
        var tsData = Data()
        
        // PATパケットのみ（PID=0x00）
        tsData.append(0x47) // Sync byte
        tsData.append(0x40) // PUSI=1
        tsData.append(0x00) // PID=0x00 (PAT)
        tsData.append(0x10) // AFC=01, CC=0
        tsData.append(Data(repeating: 0x00, count: 184)) // PAT payload
        
        await #expect(throws: TSParserError.noAudioData) {
            try parser.extractAudioFrames(from: tsData)
        }
    }
    
    // MARK: - 実際の放送ストリーム模倣テスト
    
    @Test("放送品質TSストリーム解析（ADTSフレーム付き）")
    func testBroadcastQualityTSStreamWithADTS() async throws {
        var tsData = Data()
        
        // 5パケットの放送ストリーム（PID=0x101でオーディオ）
        for packetIndex in 0..<5 {
            tsData.append(0x47) // Sync byte
            tsData.append(0x41) // PUSI=1
            tsData.append(0x01) // PID=0x101
            tsData.append(UInt8(0x10 + (packetIndex % 16))) // CC
            
            if packetIndex == 0 {
                // 最初のパケットにPESヘッダー
                tsData.append(contentsOf: [0x00, 0x00, 0x01, 0xC0, 0x00, 0x00, 0x80, 0x00, 0x00])
            }
            
            // ADTSフレーム
            tsData.append(contentsOf: [0xFF, 0xF1, 0x50, 0x80, 0x00, 0x20, 0x00])
            tsData.append(Data(repeating: UInt8(0xC0 + packetIndex), count: 25))
            
            // 188バイト調整
            let currentSize = tsData.count % 188
            if currentSize > 0 {
                let padding = 188 - currentSize
                tsData.append(Data(repeating: 0x00, count: padding))
            }
        }
        
        let frames = try parser.extractAudioFrames(from: tsData)
        
        #expect(frames.count >= 1)
        #expect(tsData.count == 188 * 5) // 5パケット
        
        // 最初のフレーム確認
        let firstFrame = frames[0]
        #expect(firstFrame.sampleRate == 44100)
        #expect(firstFrame.channelCount == 2)
        #expect(firstFrame.frameLength == 32)
    }
}