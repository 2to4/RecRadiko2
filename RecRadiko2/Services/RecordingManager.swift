//
//  RecordingManager.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/26.
//

import Foundation

private let logger = AppLogger.shared.category("RecordingManager")


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
         outputFormat: String = "m4a",
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
    
    init(authService: AuthServiceProtocol? = nil,
         apiService: RadikoAPIServiceProtocol? = nil,
         m3u8Parser: M3U8Parser = M3U8Parser(),
         streamingDownloader: StreamingDownloader = StreamingDownloader(),
         fileManager: FileManager = .default) {
        
        // 依存関係の初期化（共通のHTTPクライアントを使用）
        let httpClient = RealHTTPClient()
        self.authService = authService ?? RadikoAuthService(httpClient: httpClient)
        self.apiService = apiService ?? RadikoAPIService(httpClient: httpClient)
        self.m3u8Parser = m3u8Parser
        self.streamingDownloader = streamingDownloader
        self.fileManager = fileManager
        
        print("✅ [RecordingManager] 初期化完了")
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
        logger.info("録音実行開始: ID=\(recordingId), 放送局=\(settings.stationId)")
        logger.debug("録音設定: 開始=\(settings.startTime), 終了=\(settings.endTime), 出力=\(settings.outputDirectory.path)")
        
        // 録音時間の妥当性チェック
        let currentTime = Date()
        let timeDifference = settings.startTime.timeIntervalSince(currentTime)
        logger.info("現在時刻: \(currentTime)")
        logger.info("録音開始時刻: \(settings.startTime)")
        logger.info("時間差: \(timeDifference)秒 (\(timeDifference/3600)時間)")
        
        // Radikoタイムフリー制限チェック（1週間以内）
        let oneWeekAgo = currentTime.addingTimeInterval(-7 * 24 * 3600)
        let oneDayFuture = currentTime.addingTimeInterval(24 * 3600)
        
        if settings.startTime < oneWeekAgo {
            logger.error("録音エラー: 番組が古すぎます（1週間以上前）")
            await updateProgress(recordingId: recordingId, state: .failed(RecordingError.invalidPlaylistFormat))
            return
        }
        
        if settings.startTime > oneDayFuture {
            logger.error("録音エラー: 番組が未来すぎます（1日以上先）")
            await updateProgress(recordingId: recordingId, state: .failed(RecordingError.invalidPlaylistFormat))
            return
        }
        
        logger.info("録音時間チェック完了: 有効な時間範囲内")
        
        do {
            // 1. 認証
            logger.info("ステップ1: 認証開始")
            await updateProgress(recordingId: recordingId, state: .authenticating)
            try await authenticateIfNeeded()
            logger.info("ステップ1: 認証完了")
            
            // 2. 番組情報取得
            logger.info("ステップ2: 番組情報取得開始")
            let program = try await fetchProgramInfo(stationId: settings.stationId, 
                                                   startTime: settings.startTime)
            if let program = program {
                logger.info("ステップ2: 番組情報取得完了: \(program.title)")
            } else {
                logger.warning("ステップ2: 番組情報が見つかりません")
            }
            
            // 3. プレイリスト取得
            logger.info("ステップ3: プレイリスト取得開始")
            await updateProgress(recordingId: recordingId, state: .fetchingPlaylist)
            let playlistURL = try await buildPlaylistURL(settings: settings)
            logger.info("プレイリストURL: \(playlistURL)")
            
            let playlist = try await fetchPlaylist(from: playlistURL)
            logger.info("ステップ3: プレイリスト取得完了: \(playlist.segments.count)セグメント")
            
            // セグメント数の妥当性チェック
            if playlist.segments.isEmpty {
                logger.error("プレイリストにセグメントが含まれていません")
                await updateProgress(recordingId: recordingId, state: .failed(RecordingError.noData))
                return
            }
            
            // セグメントURLの最初の数個をログ出力
            for (index, segment) in playlist.segments.prefix(3).enumerated() {
                logger.debug("セグメント\(index + 1): \(segment.url)")
            }
            
            await updateProgress(recordingId: recordingId, 
                               state: .downloading,
                               totalSegments: playlist.segments.count,
                               currentProgram: program)
            
            // 4. セグメントダウンロード
            logger.info("ステップ4: セグメントダウンロード開始")
            let segments = try await downloadSegments(playlist: playlist, 
                                                    settings: settings,
                                                    recordingId: recordingId)
            logger.info("ステップ4: セグメントダウンロード完了: \(segments.count)セグメント")
            
            // ダウンロードされたデータサイズを確認
            let totalBytes = segments.reduce(0) { $0 + $1.data.count }
            logger.info("ダウンロード総サイズ: \(totalBytes)バイト (\(totalBytes/1024/1024)MB)")
            
            if totalBytes == 0 {
                logger.error("セグメントデータが空です")
                await updateProgress(recordingId: recordingId, state: .failed(RecordingError.noData))
                return
            }
            
            // 5. ファイル保存
            logger.info("ステップ5: ファイル保存開始")
            await updateProgress(recordingId: recordingId, state: .saving)
            try await saveRecording(segments: segments, 
                                  settings: settings, 
                                  program: program)
            logger.info("ステップ5: ファイル保存完了")
            
            // 6. 完了
            logger.info("録音実行完了: ID=\(recordingId)")
            await updateProgress(recordingId: recordingId, state: .completed)
            
        } catch {
            logger.error("録音エラー: \(error)")
            logger.error("エラー詳細: \(error.localizedDescription)")
            
            // エラータイプ別の詳細ログ
            if let recordingError = error as? RecordingError {
                logger.error("RecordingError詳細: \(recordingError)")
            } else if let httpError = error as? HTTPError {
                logger.error("HTTPError詳細: \(httpError)")
            } else {
                logger.error("Unknown Error: \(type(of: error))")
            }
            
            // より詳細なエラー情報を生成
            let detailedError: Error
            if let recordingError = error as? RecordingError {
                detailedError = recordingError
            } else if let httpError = error as? HTTPError {
                detailedError = RecordingError.networkError(httpError)
            } else {
                detailedError = RecordingError.unknown(error.localizedDescription)
            }
            
            await updateProgress(recordingId: recordingId, state: .failed(detailedError))
        }
    }
    
    /// 認証チェック
    private func authenticateIfNeeded() async throws {
        logger.info("認証状態確認開始")
        if !authService.isAuthenticated() {
            logger.info("認証が必要、認証プロセス開始")
            _ = try await authService.authenticate()
            logger.info("認証完了")
        } else {
            logger.info("既に認証済み、認証をスキップ")
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
        logger.info("プレイリストURL構築開始: \(settings.stationId)")
        
        let ftFormatter = DateFormatter()
        ftFormatter.dateFormat = "yyyyMMddHHmmss"
        
        let ft = ftFormatter.string(from: settings.startTime)
        let to = ftFormatter.string(from: settings.endTime)
        
        logger.debug("録音時刻パラメータ: ft=\(ft), to=\(to)")
        
        // 認証情報を取得
        guard let authInfo = authService.currentAuthInfo else {
            logger.error("認証情報が取得できません")
            throw RecordingError.authenticationError
        }
        
        logger.debug("認証情報取得成功: token=\(authInfo.authToken.prefix(10))..., area=\(authInfo.areaId)")
        
        let streamingURL = try streamingDownloader.buildStreamingURL(
            stationId: settings.stationId,
            ft: ft,
            to: to
        )
        
        logger.info("ストリーミングURL構築完了: \(streamingURL)")
        return streamingURL
    }
    
    /// プレイリスト取得
    private func fetchPlaylist(from urlString: String) async throws -> M3U8Playlist {
        logger.info("プレイリスト取得開始: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            logger.error("無効なURL: \(urlString)")
            throw RecordingError.playlistFetchFailed
        }
        
        // 認証情報を取得してヘッダーに追加
        guard let authInfo = authService.currentAuthInfo else {
            logger.error("認証情報が取得できません（プレイリスト取得時）")
            throw RecordingError.authenticationError
        }
        
        // Radiko API仕様書 3.2節に従って認証ヘッダーを設定
        let headers = [
            "X-Radiko-AuthToken": authInfo.authToken,
            "X-Radiko-AreaId": authInfo.areaId,
            "User-Agent": "curl/7.56.1",
            "Accept": "*/*",
            "Accept-Encoding": "gzip, deflate, br",
            "Connection": "keep-alive"
        ]
        
        logger.debug("認証ヘッダー設定: token=\(authInfo.authToken.prefix(10))..., area=\(authInfo.areaId)")
        
        // HTTPクライアントを使用してプレイリストを取得
        let httpClient = RealHTTPClient()
        logger.debug("HTTPリクエスト開始: \(url)")
        
        let playlistData: Data
        let playlistContent: String
        
        do {
            playlistData = try await httpClient.requestData(url, method: .get, headers: headers, body: nil)
            logger.info("HTTPレスポンス受信成功: \(playlistData.count)バイト")
            
            guard let content = String(data: playlistData, encoding: .utf8) else {
                logger.error("プレイリストデータのデコードに失敗")
                throw RecordingError.playlistFetchFailed
            }
            playlistContent = content
            
            // HTTPレスポンスのステータスコードをログ出力（可能であれば）
            if playlistContent.contains("404") || playlistContent.contains("Not Found") {
                logger.error("404エラーを含むレスポンス: \(String(playlistContent.prefix(200)))")
                throw RecordingError.playlistFetchFailed
            }
            
            if playlistContent.contains("error") || playlistContent.contains("Error") {
                logger.error("エラーを含むレスポンス: \(String(playlistContent.prefix(200)))")
                throw RecordingError.playlistFetchFailed
            }
        } catch {
            logger.error("HTTPリクエスト失敗: \(error)")
            logger.error("エラー詳細: \(error.localizedDescription)")
            throw RecordingError.playlistFetchFailed
        }
        
        logger.info("プレイリスト取得成功: \(playlistContent.count)文字")
        logger.debug("プレイリスト内容（最初の200文字）: \(String(playlistContent.prefix(200)))")
        
        // マスタープレイリストかセグメントプレイリストかを判定
        if playlistContent.contains("#EXT-X-STREAM-INF") {
            // マスタープレイリスト: サブプレイリストURLを抽出
            logger.info("マスタープレイリストを検出、サブプレイリストを取得")
            let subPlaylistURL = try extractSubPlaylistURL(from: playlistContent, baseURL: url)
            logger.info("サブプレイリストURL: \(subPlaylistURL)")
            
            // サブプレイリストを取得
            guard let subURL = URL(string: subPlaylistURL) else {
                logger.error("無効なサブプレイリストURL: \(subPlaylistURL)")
                throw RecordingError.playlistFetchFailed
            }
            
            let subPlaylistData = try await httpClient.requestData(subURL, method: .get, headers: headers, body: nil)
            guard let subPlaylistContent = String(data: subPlaylistData, encoding: .utf8) else {
                logger.error("サブプレイリストデータのデコードに失敗")
                throw RecordingError.playlistFetchFailed
            }
            
            logger.info("サブプレイリスト取得成功: \(subPlaylistContent.count)文字")
            logger.debug("サブプレイリスト内容（最初の200文字）: \(String(subPlaylistContent.prefix(200)))")
            
            return try m3u8Parser.parse(subPlaylistContent, baseURL: subURL)
        } else {
            // セグメントプレイリスト: 直接解析
            logger.info("セグメントプレイリストを直接解析")
            return try m3u8Parser.parse(playlistContent, baseURL: url)
        }
    }
    
    /// マスタープレイリストからサブプレイリストURLを抽出
    private func extractSubPlaylistURL(from content: String, baseURL: URL) throws -> String {
        let lines = content.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            if line.contains("#EXT-X-STREAM-INF") {
                // 次の行がプレイリストURL
                if index + 1 < lines.count {
                    let urlLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !urlLine.hasPrefix("#") {
                        // 相対URLの場合は絶対URLに変換
                        if urlLine.hasPrefix("http") {
                            return urlLine
                        } else {
                            return baseURL.deletingLastPathComponent().appendingPathComponent(urlLine).absoluteString
                        }
                    }
                }
            }
        }
        
        logger.error("サブプレイリストURLが見つかりません")
        throw RecordingError.playlistFetchFailed
    }
    
    /// セグメントダウンロード（メモリ効率改善版）
    private func downloadSegments(playlist: M3U8Playlist, 
                                settings: RecordingSettings,
                                recordingId: String) async throws -> [SegmentDownloadResult] {
        
        logger.info("セグメントダウンロード開始: \(playlist.segments.count)個")
        
        // 認証情報を取得してStreamingDownloaderに設定
        guard let authInfo = authService.currentAuthInfo else {
            logger.error("認証情報が取得できません（セグメントダウンロード時）")
            throw RecordingError.authenticationError
        }
        
        // StreamingDownloaderに認証ヘッダーを設定
        streamingDownloader.setAuthHeaders(authToken: authInfo.authToken, areaId: authInfo.areaId)
        logger.debug("StreamingDownloaderに認証ヘッダーを設定完了")
        
        // downloadSegmentsConcurrentlyメソッドを正しいシグネチャで呼び出し
        return try await streamingDownloader.downloadSegmentsConcurrently(
            playlist.segments,
            maxConcurrent: settings.maxConcurrentDownloads,
            resultHandler: { result in
                // 各セグメント完了時のコールバック
                logger.debug("セグメント完了: \(result.url) (\(result.data.count)バイト)")
            }
        )
    }
    
    /// 録音保存（メタデータ・重複チェック・容量確認対応）
    private func saveRecording(segments: [SegmentDownloadResult], 
                             settings: RecordingSettings,
                             program: RadioProgram?) async throws {
        
        logger.info("ファイル保存開始: セグメント数=\(segments.count)")
        logger.debug("保存先ディレクトリ: \(settings.outputDirectory.path)")
        
        // セグメントが空の場合のチェック
        guard !segments.isEmpty else {
            logger.error("セグメントが空です。録音データがありません")
            throw RecordingError.noData
        }
        
        // 1. 出力ディレクトリ作成
        do {
            try fileManager.createDirectory(at: settings.outputDirectory, 
                                          withIntermediateDirectories: true)
            logger.info("出力ディレクトリ作成成功: \(settings.outputDirectory.path)")
        } catch {
            logger.error("出力ディレクトリ作成失敗: \(error)")
            throw RecordingError.saveFailed
        }
        
        // 2. セグメントデータを結合
        var combinedData = Data()
        for (index, segment) in segments.enumerated() {
            logger.debug("セグメント\(index + 1)/\(segments.count)を結合中: \(segment.data.count)バイト")
            combinedData.append(segment.data)
        }
        logger.info("セグメント結合完了: 合計\(combinedData.count)バイト")
        
        // 3. 容量チェック（予想サイズの1.2倍のマージンを確保）
        let requiredSpace = Int64(combinedData.count) * 12 / 10
        logger.debug("必要容量: \(requiredSpace)バイト")
        do {
            try await checkAvailableSpace(at: settings.outputDirectory, required: requiredSpace)
            logger.info("容量チェック成功")
        } catch {
            logger.error("容量チェック失敗: \(error)")
            throw error
        }
        
        // 4. ファイル名生成（重複回避）
        let outputFile: URL
        do {
            outputFile = try await generateUniqueFilename(
                settings: settings, 
                program: program
            )
            logger.info("出力ファイル名生成完了: \(outputFile.lastPathComponent)")
            logger.debug("出力ファイルパス: \(outputFile.path)")
        } catch {
            logger.error("ファイル名生成失敗: \(error)")
            throw error
        }
        
        // 5. 一時ファイル書き込み
        let tempFile = outputFile.appendingPathExtension("tmp")
        logger.debug("一時ファイルパス: \(tempFile.path)")
        
        do {
            try combinedData.write(to: tempFile)
            logger.info("一時ファイル書き込み成功: \(tempFile.lastPathComponent)")
            
            // ファイルサイズ確認
            if let attributes = try? fileManager.attributesOfItem(atPath: tempFile.path),
               let fileSize = attributes[.size] as? Int64 {
                logger.info("書き込まれたファイルサイズ: \(fileSize)バイト")
            }
        } catch {
            logger.error("一時ファイル書き込み失敗: \(error)")
            logger.error("エラー詳細: \(error.localizedDescription)")
            throw RecordingError.saveFailed
        }
        
        // 6. メタデータ埋め込み（将来拡張用）
        do {
            try await embedMetadata(tempFile: tempFile, outputFile: outputFile, program: program)
            logger.info("メタデータ埋め込み完了")
        } catch {
            logger.error("メタデータ埋め込み失敗: \(error)")
            // 一時ファイル削除
            try? fileManager.removeItem(at: tempFile)
            throw RecordingError.saveFailed
        }
        
        // 7. 最終ファイル確認
        if fileManager.fileExists(atPath: outputFile.path) {
            logger.info("録音ファイル保存成功: \(outputFile.path)")
            if let attributes = try? fileManager.attributesOfItem(atPath: outputFile.path),
               let fileSize = attributes[.size] as? Int64 {
                logger.info("最終ファイルサイズ: \(fileSize)バイト")
            }
        } else {
            logger.error("録音ファイルが見つかりません: \(outputFile.path)")
            throw RecordingError.saveFailed
        }
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
        logger.info("メタデータ埋め込み開始")
        logger.debug("一時ファイル: \(tempFile.path)")
        logger.debug("出力ファイル: \(outputFile.path)")
        
        // 現在は単純なファイル移動
        // 将来的にはID3タグやメタデータ埋め込みを実装予定
        do {
            try fileManager.moveItem(at: tempFile, to: outputFile)
            logger.info("ファイル移動成功: \(tempFile.lastPathComponent) -> \(outputFile.lastPathComponent)")
        } catch {
            logger.error("ファイル移動失敗: \(error)")
            logger.error("エラー詳細: \(error.localizedDescription)")
            throw error
        }
        
        // メタデータ情報をログ出力（デバッグ用）
        if let program = program {
            logger.info("録音完了: \(program.title) (\(program.stationId)) -> \(outputFile.lastPathComponent)")
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