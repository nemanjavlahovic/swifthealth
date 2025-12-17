import XCTest
@testable import Core

/// Original placeholder test file
/// Real tests are in ScoreEngineTests.swift, ConfigLoaderTests.swift, MetricTests.swift
final class SwiftHealthTests: XCTestCase {
    func testDefaultConfigExists() throws {
        // Verify default config can be created
        let config = Config.default()
        XCTAssertEqual(config.version, 1)
    }
}
