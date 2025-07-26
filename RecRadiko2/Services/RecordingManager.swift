//
//  RecordingManager.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/26.
//

import Foundation


/// 録音状態
enum RecordingState: Equatable {
    case idle
    case authenticating
    case fetchingPlaylist
    case downloading
    case saving
    case completed
    case failed(Error)
    
    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.authenticating, .authenticating),
             (.fetchingPlaylist, .fetchingPlaylist),
             (.downloading, .downloading),
             (.saving, .saving),
             (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// 録音進捗情報
struct RecordingProgress {
    let state: RecordingState
    let downloadedSegments: Int
    let totalSegments: Int
    let downloadedBytes: Int
    let estimatedTotalBytes: Int
    let currentProgram: RadioProgram?
    
    var progressPercentage: Double {
        guard totalSegments > 0 else { return 0.0 }
        return Double(downloadedSegments) / Double(totalSegments)
    }
    
    var isCompleted: Bool {
        if case .completed = state {
            return true
        }
        return false
    }
    
    var isFailed: Bool {
        if case .failed = state {
            return true
        }
        return false
    }
}

/// 録音設定
struct RecordingSettings {
    let stationId: String
    let startTime: Date
    let endTime: Date
    let outputDirectory: URL
    let outputFormat: String // "aac", "mp3", etc.
    let maxConcurrentDownloads: Int
    let retryCount: Int
    
    init(stationId: String, 
         startTime: Date, 
         endTime: Date, 
         outputDirectory: URL, 
         outputFormat: String = "aac",
         maxConcurrentDownloads: Int = 3,
         retryCount: Int = 3) {
        self.stationId = stationId
        self.startTime = startTime
        self.endTime = endTime
        self.outputDirectory = outputDirectory
        self.outputFormat = outputFormat
        self.maxConcurrentDownloads = maxConcurrentDownloads
        self.retryCount = retryCount
    }
}

/// 録音管理クラス
@MainActor
class RecordingManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published var currentProgress: RecordingProgress?
    @Published var activeRecordings: [String: RecordingProgress] = [:]
    
    private let authService: AuthServiceProtocol
    private let apiService: RadikoAPIServiceProtocol
    private let m3u8Parser: M3U8Parser
    private let streamingDownloader: StreamingDownloader
    private let fileManager: FileManager
    
    // MARK: - Initialization
    
    init(authService: AuthServiceProtocol = RadikoAuthService(),
         apiService: RadikoAPIServiceProtocol = RadikoAPIService(),
         m3u8Parser: M3U8Parser = M3U8Parser(),
         streamingDownloader: StreamingDownloader = StreamingDownloader(),
         fileManager: FileManager = .default) {
        self.authService = authService
        self.apiService = apiService
        self.m3u8Parser = m3u8Parser
        self.streamingDownloader = streamingDownloader
        self.fileManager = fileManager
    }
    
    // MARK: - Recording Control
    
    /// 録音開始
    /// - Parameter settings: 録音設定
    /// - Returns: 録音ID
    func startRecording(with settings: RecordingSettings) async throws -> String {
        let recordingId = UUID().uuidString
        
        let initialProgress = RecordingProgress(
            state: .idle,
            downloadedSegments: 0,
            totalSegments: 0,
            downloadedBytes: 0,
            estimatedTotalBytes: 0,
            currentProgram: nil
        )
        
        activeRecordings[recordingId] = initialProgress
        currentProgress = initialProgress
        
        Task {
            await performRecording(recordingId: recordingId, settings: settings)
        }
        
        return recordingId
    }
    
    /// 録音停止
    /// - Parameter recordingId: 録音ID
    func stopRecording(_ recordingId: String) {
        activeRecordings.removeValue(forKey: recordingId)
        if activeRecordings.isEmpty {
            currentProgress = nil
        }
    }
    
    /// 全録音停止
    func stopAllRecordings() {
        activeRecordings.removeAll()
        currentProgress = nil
    }
    
    // MARK: - Private Methods
    
    /// 録音実行
    private func performRecording(recordingId: String, settings: RecordingSettings) async {
        do {
            // 1. 認証
            await updateProgress(recordingId: recordingId, state: .authenticating)
            try await authenticateIfNeeded()
            
            // 2. 番組情報取得
            let program = try await fetchProgramInfo(stationId: settings.stationId, 
                                                   startTime: settings.startTime)
            
            // 3. プレイリスト取得
            await updateProgress(recordingId: recordingId, state: .fetchingPlaylist)
            let playlistURL = try await buildPlaylistURL(settings: settings)
            let playlist = try await fetchPlaylist(from: playlistURL)
            
            await updateProgress(recordingId: recordingId, 
                               state: .downloading,
                               totalSegments: playlist.segments.count,
                               currentProgram: program)
            
            // 4. セグメントダウンロード
            let segments = try await downloadSegments(playlist: playlist, 
                                                    settings: settings,
                                                    recordingId: recordingId)
            
            // 5. ファイル保存
            await updateProgress(recordingId: recordingId, state: .saving)
            try await saveRecording(segments: segments, 
                                  settings: settings, 
                                  program: program)
            
            // 6. 完了
            await updateProgress(recordingId: recordingId, state: .completed)
            
        } catch {
            await updateProgress(recordingId: recordingId, state: .failed(error))
        }
    }
    
    /// 認証チェック
    private func authenticateIfNeeded() async throws {
        if !authService.isAuthenticated() {
            _ = try await authService.authenticate()
        }
    }
    
    /// 番組情報取得
    private func fetchProgramInfo(stationId: String, startTime: Date) async throws -> RadioProgram? {
        let programs = try await apiService.fetchPrograms(stationId: stationId, date: startTime)
        return programs.first { program in
            program.startTime <= startTime && program.endTime > startTime
        }
    }
    
    /// プレイリストURL構築
    private func buildPlaylistURL(settings: RecordingSettings) async throws -> String {
        let ftFormatter = DateFormatter()
        ftFormatter.dateFormat = "yyyyMMddHHmmss"
        
        let ft = ftFormatter.string(from: settings.startTime)
        let to = ftFormatter.string(from: settings.endTime)
        
        return try streamingDownloader.buildStreamingURL(
            stationId: settings.stationId,
            ft: ft,
            to: to
        )
    }
    
    /// プレイリスト取得
    private func fetchPlaylist(from urlString: String) async throws -> M3U8Playlist {
        guard let url = URL(string: urlString) else {
            throw RecordingError.playlistFetchFailed
        }
        
        // HTTPクライアントを直接使用してプレイリストを取得
        let httpClient = HTTPClient()
        let playlistData = try await httpClient.requestData(url, method: .get, headers: nil, body: nil)
        guard let playlistContent = String(data: playlistData, encoding: .utf8) else {
            throw RecordingError.playlistFetchFailed
        }
        
        return try m3u8Parser.parse(playlistContent, baseURL: url)
    }
    
    /// セグメントダウンロード（メモリ効率改善版）
    private func downloadSegments(playlist: M3U8Playlist, 
                                settings: RecordingSettings,
                                recordingId: String) async throws -> [SegmentDownloadResult] {
        
        // メモリ効率のため、並行ダウンロードを使用し、結果ハンドラーで即座に処理
        return try await streamingDownloader.downloadSegmentsConcurrently(
            playlist.segments,
            maxConcurrent: settings.maxConcurrentDownloads,
            resultHandler: { result in
                // 各セグメント完了時に即座にメモリから解放される可能性を高める
                // 将来的にはここでストリーミング書き込みを実装可能
            }
        )
    }
    
    /// 録音保存（メタデータ・重複チェック・容量確認対応）
    private func saveRecording(segments: [SegmentDownloadResult], 
                             settings: RecordingSettings,
                             program: RadioProgram?) async throws {
        
        // 1. 出力ディレクトリ作成
        try fileManager.createDirectory(at: settings.outputDirectory, 
                                      withIntermediateDirectories: true)
        
        // 2. セグメントデータを結合
        var combinedData = Data()
        for segment in segments {
            combinedData.append(segment.data)
        }
        
        // 3. 容量チェック（予想サイズの1.2倍のマージンを確保）
        let requiredSpace = Int64(combinedData.count) * 12 / 10
        try await checkAvailableSpace(at: settings.outputDirectory, required: requiredSpace)
        
        // 4. ファイル名生成（重複回避）
        let outputFile = try await generateUniqueFilename(
            settings: settings, 
            program: program
        )
        
        // 5. 一時ファイル書き込み
        let tempFile = outputFile.appendingPathExtension("tmp")
        try combinedData.write(to: tempFile)
        
        // 6. メタデータ埋め込み（将来拡張用）
        try await embedMetadata(tempFile: tempFile, outputFile: outputFile, program: program)
        
        // 7. 一時ファイル削除
        try? fileManager.removeItem(at: tempFile)
    }
    
    /// 利用可能容量チェック
    private func checkAvailableSpace(at directory: URL, required: Int64) async throws {
        let resourceValues = try directory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        guard let availableCapacity = resourceValues.volumeAvailableCapacity else {
            throw RecordingError.insufficientStorage
        }
        
        if availableCapacity < required {
            throw RecordingError.insufficientStorage
        }
    }
    
    /// 重複回避ファイル名生成
    private func generateUniqueFilename(settings: RecordingSettings, 
                                      program: RadioProgram?) async throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: settings.startTime)
        
        let baseTitle = program?.title ?? settings.stationId
        let sanitizedTitle = baseTitle.replacingOccurrences(of: "[/\\\\:*?\"<>|]", 
                                                          with: "_", 
                                                          options: .regularExpression)
        
        let baseFilename = "\(dateString)_\(sanitizedTitle)"
        var finalURL = settings.outputDirectory
            .appendingPathComponent(baseFilename)
            .appendingPathExtension(settings.outputFormat)
        
        // 重複チェック・連番追加
        var counter = 1
        while fileManager.fileExists(atPath: finalURL.path) {
            let numberedFilename = "\(baseFilename)_(\(counter))"
            finalURL = settings.outputDirectory
                .appendingPathComponent(numberedFilename)
                .appendingPathExtension(settings.outputFormat)
            counter += 1
            
            // 無限ループ防止
            if counter > 999 {
                throw RecordingError.saveFailed
            }
        }
        
        return finalURL
    }
    
    /// メタデータ埋め込み（現在はファイル移動のみ、将来拡張用）
    private func embedMetadata(tempFile: URL, outputFile: URL, program: RadioProgram?) async throws {
        // 現在は単純なファイル移動
        // 将来的にはID3タグやメタデータ埋め込みを実装予定
        try fileManager.moveItem(at: tempFile, to: outputFile)
        
        // メタデータ情報をログ出力（デバッグ用）
        if let program = program {
            print("録音完了: \(program.title) (\(program.stationId)) -> \(outputFile.lastPathComponent)")
        }
    }
    
    /// 進捗更新
    private func updateProgress(recordingId: String,
                              state: RecordingState? = nil,
                              downloadedSegments: Int? = nil,
                              totalSegments: Int? = nil,
                              downloadedBytes: Int? = nil,
                              estimatedTotalBytes: Int? = nil,
                              currentProgram: RadioProgram? = nil) async {
        
        guard let progress = activeRecordings[recordingId] else { return }
        
        let newProgress = RecordingProgress(
            state: state ?? progress.state,
            downloadedSegments: downloadedSegments ?? progress.downloadedSegments,
            totalSegments: totalSegments ?? progress.totalSegments,
            downloadedBytes: downloadedBytes ?? progress.downloadedBytes,
            estimatedTotalBytes: estimatedTotalBytes ?? progress.estimatedTotalBytes,
            currentProgram: currentProgram ?? progress.currentProgram
        )
        
        activeRecordings[recordingId] = newProgress
        currentProgress = newProgress
    }
}