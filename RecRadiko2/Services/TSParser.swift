//
//  TSParser.swift
//  RecRadiko2
//
//  Created by Claude on 2025/08/12.
//

import Foundation

/// TSパケットヘッダー構造
struct TSPacketHeader {
    let syncByte: UInt8
    let transportErrorIndicator: Bool
    let payloadUnitStartIndicator: Bool
    let transportPriority: Bool
    let pid: UInt16
    let scramblingControl: UInt8
    let adaptationFieldControl: UInt8
    let continuityCounter: UInt8
    
    init(data: Data) throws {
        guard data.count >= 4 else {
            throw TSParserError.invalidPacketSize
        }
        
        syncByte = data[0]
        guard syncByte == 0x47 else {
            throw TSParserError.invalidSyncByte
        }
        
        let byte1 = data[1]
        let byte2 = data[2]
        let byte3 = data[3]
        
        transportErrorIndicator = (byte1 & 0x80) != 0
        payloadUnitStartIndicator = (byte1 & 0x40) != 0
        transportPriority = (byte1 & 0x20) != 0
        pid = UInt16((byte1 & 0x1F)) << 8 | UInt16(byte2)
        scramblingControl = (byte3 & 0xC0) >> 6
        adaptationFieldControl = (byte3 & 0x30) >> 4
        continuityCounter = byte3 & 0x0F
    }
}

/// TSパーサーエラー
enum TSParserError: Error, LocalizedError {
    case invalidPacketSize
    case invalidSyncByte
    case noAudioData
    case unsupportedStreamType
    
    var errorDescription: String? {
        switch self {
        case .invalidPacketSize:
            return "TSパケットサイズが無効です"
        case .invalidSyncByte:
            return "TSパケット同期バイトが無効です"
        case .noAudioData:
            return "オーディオデータが見つかりません"
        case .unsupportedStreamType:
            return "サポートされていないストリーム形式です"
        }
    }
}

/// ADTS ADU (Audio Data Unit)
struct ADTSFrame {
    let data: Data
    let sampleRate: Int
    let channelCount: Int
    let frameLength: Int
    
    init(data: Data) throws {
        guard data.count >= 7 else {
            throw TSParserError.noAudioData
        }
        
        // ADTSヘッダー解析
        guard data[0] == 0xFF && (data[1] & 0xF0) == 0xF0 else {
            throw TSParserError.noAudioData
        }
        
        // サンプリングレート取得
        let samplingFreqIndex = (data[2] & 0x3C) >> 2
        let sampleRates = [96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350]
        guard samplingFreqIndex < sampleRates.count else {
            throw TSParserError.unsupportedStreamType
        }
        sampleRate = sampleRates[Int(samplingFreqIndex)]
        
        // チャンネル数取得
        channelCount = Int((data[2] & 0x01) << 2 | (data[3] & 0xC0) >> 6)
        
        // フレーム長取得
        frameLength = Int((data[3] & 0x03) << 11 | (data[4]) << 3 | (data[5] & 0xE0) >> 5)
        
        self.data = data
    }
}

/// TSストリームパーサー
class TSParser {
    private let logger = AppLogger.shared.category("TSParser")
    
    /// TSセグメントからAACオーディオデータを抽出
    /// - Parameter tsData: TSセグメントデータ
    /// - Returns: 抽出されたAACオーディオフレーム配列
    func extractAudioFrames(from tsData: Data) throws -> [ADTSFrame] {
        logger.info("TSパーサー開始: \(tsData.count)バイト")
        
        // データの最初の16バイトをログ出力（デバッグ用）
        let headerData = tsData.prefix(16)
        let headerHex = headerData.map { String(format: "%02X", $0) }.joined(separator: " ")
        logger.debug("データヘッダー: \(headerHex)")
        
        var audioFrames: [ADTSFrame] = []
        var audioPID: UInt16?
        var pesBuffer = Data()
        var currentPacketCount = 0
        
        // TSパケットは188バイト固定
        let packetSize = 188
        let totalPackets = tsData.count / packetSize
        
        logger.debug("TSパケット数: \(totalPackets)")
        
        // データがTSパケット形式でない可能性をチェック
        var syncByteFound = false
        for i in 0..<min(188, tsData.count) {
            if tsData[i] == 0x47 {
                syncByteFound = true
                if i > 0 {
                    logger.warning("同期バイトがオフセット\(i)で発見されました。データ開始位置が異なる可能性があります")
                }
                break
            }
        }
        
        if !syncByteFound {
            logger.error("TSパケットの同期バイト(0x47)が見つかりません。データが暗号化されているか、形式が異なります")
            // データの内容を確認
            if let stringData = String(data: tsData.prefix(100), encoding: .utf8) {
                logger.error("データの文字列表現: \(stringData)")
            }
        }
        
        for packetIndex in 0..<totalPackets {
            let packetStart = packetIndex * packetSize
            guard packetStart + packetSize <= tsData.count else { break }
            
            let packetData = tsData.subdata(in: packetStart..<(packetStart + packetSize))
            
            do {
                let header = try TSPacketHeader(data: packetData)
                currentPacketCount += 1
                
                // 同期バイトチェック
                guard header.syncByte == 0x47 else {
                    logger.debug("無効な同期バイト: パケット\(packetIndex)")
                    continue
                }
                
                // 最初のパケットでオーディオPIDを特定
                if audioPID == nil && header.pid != 0x00 && header.pid != 0x11 {
                    // PAT (0x00), SDT (0x11) 以外をオーディオとして扱う
                    audioPID = header.pid
                    logger.info("オーディオPID発見: 0x\(String(header.pid, radix: 16, uppercase: true))")
                }
                
                // オーディオPIDのパケットのみ処理
                guard let targetPID = audioPID, header.pid == targetPID else {
                    continue
                }
                
                // ペイロード開始位置計算
                var payloadStart = 4
                
                // アダプテーションフィールドの処理
                if header.adaptationFieldControl == 0x02 || header.adaptationFieldControl == 0x03 {
                    if packetData.count > 4 {
                        let adaptationLength = packetData[4]
                        payloadStart += Int(adaptationLength) + 1
                    }
                }
                
                // ペイロードが存在しない場合はスキップ
                guard header.adaptationFieldControl != 0x02 else { continue }
                guard payloadStart < packetData.count else { continue }
                
                let payload = packetData.subdata(in: payloadStart..<packetData.count)
                
                // PESヘッダー開始の場合
                if header.payloadUnitStartIndicator {
                    // 前のPESパケットを処理
                    if !pesBuffer.isEmpty {
                        let extractedFrames = try extractADTSFrames(from: pesBuffer)
                        audioFrames.append(contentsOf: extractedFrames)
                        pesBuffer.removeAll()
                    }
                }
                
                // ペイロードをバッファに追加
                pesBuffer.append(payload)
                
            } catch {
                logger.debug("TSパケット解析エラー: パケット\(packetIndex), \(error)")
                continue
            }
        }
        
        // 最後のPESパケットを処理
        if !pesBuffer.isEmpty {
            let extractedFrames = try extractADTSFrames(from: pesBuffer)
            audioFrames.append(contentsOf: extractedFrames)
        }
        
        logger.info("TSパーサー完了: \(audioFrames.count)フレーム抽出")
        logger.debug("処理パケット数: \(currentPacketCount)/\(totalPackets)")
        
        guard !audioFrames.isEmpty else {
            throw TSParserError.noAudioData
        }
        
        return audioFrames
    }
    
    /// PESデータからADTSフレームを抽出
    private func extractADTSFrames(from pesData: Data) throws -> [ADTSFrame] {
        var frames: [ADTSFrame] = []
        var currentPosition = 0
        
        // PESヘッダーをスキップ
        if pesData.count >= 6 {
            let startCode = (UInt32(pesData[0]) << 16) | (UInt32(pesData[1]) << 8) | UInt32(pesData[2])
            if startCode == 0x000001 {
                let headerLength = Int(pesData[8])
                currentPosition = 9 + headerLength
            }
        }
        
        // ADTSフレームを検索・抽出
        while currentPosition < pesData.count - 7 {
            // ADTSシンクワード検索 (0xFFF)
            if pesData[currentPosition] == 0xFF && (pesData[currentPosition + 1] & 0xF0) == 0xF0 {
                // フレーム長を取得
                let frameLength = Int((pesData[currentPosition + 3] & 0x03) << 11 | 
                                    pesData[currentPosition + 4] << 3 | 
                                    (pesData[currentPosition + 5] & 0xE0) >> 5)
                
                if currentPosition + frameLength <= pesData.count && frameLength > 7 {
                    let frameData = pesData.subdata(in: currentPosition..<(currentPosition + frameLength))
                    
                    do {
                        let frame = try ADTSFrame(data: frameData)
                        frames.append(frame)
                        currentPosition += frameLength
                    } catch {
                        currentPosition += 1
                    }
                } else {
                    currentPosition += 1
                }
            } else {
                currentPosition += 1
            }
        }
        
        return frames
    }
}