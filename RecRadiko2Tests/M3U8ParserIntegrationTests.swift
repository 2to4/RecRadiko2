//
//  M3U8ParserIntegrationTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/26.
//

import XCTest
@testable import RecRadiko2

/// M3U8Parser統合テスト（XCTest使用）
class M3U8ParserIntegrationTests: XCTestCase {
    
    var parser: M3U8Parser!
    
    override func setUp() {
        super.setUp()
        parser = M3U8Parser()
    }
    
    override func tearDown() {
        parser = nil
        super.tearDown()
    }
    
    // MARK: - Basic Tests
    
    func testParseBasicM3U8() throws {
        // Given
        let m3u8Content = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:10
        #EXT-X-MEDIA-SEQUENCE:0
        #EXTINF:10.0,
        https://radiko.jp/segment0.aac
        #EXTINF:10.0,
        https://radiko.jp/segment1.aac
        #EXTINF:10.0,
        https://radiko.jp/segment2.aac
        """
        
        // When
        let playlist = try parser.parse(m3u8Content)
        
        // Then
        XCTAssertEqual(playlist.version, 3)
        XCTAssertEqual(playlist.targetDuration, 10)
        XCTAssertEqual(playlist.mediaSequence, 0)
        XCTAssertEqual(playlist.segments.count, 3)
        XCTAssertFalse(playlist.isEndList)
        
        // セグメント詳細確認
        XCTAssertEqual(playlist.segments[0].url, "https://radiko.jp/segment0.aac")
        XCTAssertEqual(playlist.segments[0].duration, 10.0)
        XCTAssertEqual(playlist.segments[1].url, "https://radiko.jp/segment1.aac")
        XCTAssertEqual(playlist.segments[2].url, "https://radiko.jp/segment2.aac")
    }
    
    func testParseInvalidM3U8() {
        // Given
        let invalidContent = "This is not a valid M3U8 file"
        
        // When & Then
        XCTAssertThrowsError(try parser.parse(invalidContent)) { error in
            XCTAssertEqual(error as? RecordingError, RecordingError.invalidPlaylistFormat)
        }
    }
    
    func testParseEmptyM3U8() throws {
        // Given
        let emptyM3U8 = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:10
        #EXT-X-MEDIA-SEQUENCE:0
        """
        
        // When
        let playlist = try parser.parse(emptyM3U8)
        
        // Then
        XCTAssertTrue(playlist.segments.isEmpty)
    }
    
    // MARK: - URL Resolution Tests
    
    func testRelativeURLResolution() throws {
        // Given
        let baseURL = URL(string: "https://radiko.jp/v2/api/ts/playlist.m3u8")!
        let relativeM3U8 = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:10
        #EXT-X-MEDIA-SEQUENCE:0
        #EXTINF:10.0,
        segment0.aac
        #EXTINF:10.0,
        ../segments/segment1.aac
        #EXTINF:10.0,
        /absolute/segment2.aac
        """
        
        // When
        let playlist = try parser.parse(relativeM3U8, baseURL: baseURL)
        
        // Then
        XCTAssertEqual(playlist.segments.count, 3)
        XCTAssertEqual(playlist.segments[0].url, "https://radiko.jp/v2/api/ts/segment0.aac")
        XCTAssertEqual(playlist.segments[1].url, "https://radiko.jp/v2/api/segments/segment1.aac")
        XCTAssertEqual(playlist.segments[2].url, "https://radiko.jp/absolute/segment2.aac")
    }
    
    // MARK: - Radiko Format Tests
    
    func testParseRadikoFormatM3U8() throws {
        // Given
        let radikoM3U8 = """
        #EXTM3U
        #EXT-X-ALLOW-CACHE:NO
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:5
        #EXT-X-MEDIA-SEQUENCE:0
        #EXTINF:5,
        https://rpaa.smartstream.ne.jp/segments/12345678/12345678_0.aac
        #EXTINF:5,
        https://rpaa.smartstream.ne.jp/segments/12345678/12345678_1.aac
        #EXTINF:5,
        https://rpaa.smartstream.ne.jp/segments/12345678/12345678_2.aac
        """
        
        // When
        let playlist = try parser.parse(radikoM3U8)
        
        // Then
        XCTAssertEqual(playlist.allowCache, false)
        XCTAssertEqual(playlist.targetDuration, 5)
        XCTAssertEqual(playlist.segments.count, 3)
        XCTAssertTrue(playlist.segments[0].url.contains("smartstream.ne.jp"))
    }
    
    func testParseLiveStreamingM3U8() throws {
        // Given
        let liveM3U8 = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:10
        #EXT-X-MEDIA-SEQUENCE:100
        #EXTINF:10.0,
        https://radiko.jp/live/segment100.aac
        #EXTINF:10.0,
        https://radiko.jp/live/segment101.aac
        #EXTINF:10.0,
        https://radiko.jp/live/segment102.aac
        #EXT-X-ENDLIST
        """
        
        // When
        let playlist = try parser.parse(liveM3U8)
        
        // Then
        XCTAssertEqual(playlist.mediaSequence, 100)
        XCTAssertTrue(playlist.isEndList)
        XCTAssertEqual(playlist.segments.count, 3)
        XCTAssertTrue(playlist.segments[0].url.contains("segment100"))
    }
}