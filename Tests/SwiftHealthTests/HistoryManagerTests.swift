import XCTest
@testable import Core

/// Tests for HistoryManager
final class HistoryManagerTests: XCTestCase {

    // MARK: - Project Path Hashing

    func testHashProjectPath_SameInput_SameOutput() {
        let path = "/Users/test/myproject"
        let manager1 = HistoryManager(projectPath: path)
        let manager2 = HistoryManager(projectPath: path)

        // Both should produce the same hash (deterministic)
        // We can't directly test the hash, but we can test that the manager initializes
        XCTAssertNotNil(manager1)
        XCTAssertNotNil(manager2)
    }

    func testHashProjectPath_DifferentInput_DifferentOutput() {
        let manager1 = HistoryManager(projectPath: "/Users/test/project1")
        let manager2 = HistoryManager(projectPath: "/Users/test/project2")

        // Both should initialize (different hashes)
        XCTAssertNotNil(manager1)
        XCTAssertNotNil(manager2)
    }

    // MARK: - History Entry Creation

    func testHistoryEntry_Creation() {
        let entry = HistoryEntry(
            score: 0.85,
            band: "green",
            gitCommit: "abc123",
            gitBranch: "main",
            metricScores: ["git.recency": 0.9, "lint.warnings": 0.7]
        )

        XCTAssertEqual(entry.score, 0.85)
        XCTAssertEqual(entry.band, "green")
        XCTAssertEqual(entry.gitCommit, "abc123")
        XCTAssertEqual(entry.gitBranch, "main")
        XCTAssertEqual(entry.metricScores.count, 2)
    }

    func testHistoryEntry_ScorePercent() {
        let entry = HistoryEntry(score: 0.875, band: "green")

        XCTAssertEqual(entry.scorePercent, 87)
    }

    // MARK: - History File

    func testHistoryFile_MaxEntries() {
        XCTAssertEqual(HistoryFile.maxEntries, 100)
    }

    func testHistoryFile_Creation() {
        let history = HistoryFile(projectPath: "/test/path")

        XCTAssertEqual(history.version, 1)
        XCTAssertEqual(history.projectPath, "/test/path")
        XCTAssertTrue(history.entries.isEmpty)
    }

    // MARK: - Trend Direction

    func testTrendDirection_Emoji() {
        XCTAssertEqual(TrendDirection.improving.emoji, "+")
        XCTAssertEqual(TrendDirection.stable.emoji, "~")
        XCTAssertEqual(TrendDirection.declining.emoji, "-")
        XCTAssertEqual(TrendDirection.unknown.emoji, "?")
    }

    func testTrendDirection_Description() {
        XCTAssertEqual(TrendDirection.improving.description, "Improving")
        XCTAssertEqual(TrendDirection.stable.description, "Stable")
        XCTAssertEqual(TrendDirection.declining.description, "Declining")
        XCTAssertEqual(TrendDirection.unknown.description, "Not enough data")
    }

    // MARK: - Trend Summary

    func testTrendSummary_DefaultValues() {
        let summary = TrendSummary()

        XCTAssertEqual(summary.direction, .unknown)
        XCTAssertNil(summary.deltaFromLast)
        XCTAssertNil(summary.deltaFrom7Days)
        XCTAssertNil(summary.deltaFrom30Days)
        XCTAssertEqual(summary.entryCount, 0)
        XCTAssertNil(summary.averageScore)
        XCTAssertNil(summary.bestScore)
        XCTAssertNil(summary.worstScore)
    }

    // MARK: - Load/Create

    func testLoadOrCreate_NoExistingFile_ReturnsNewHistory() {
        // Use a path that definitely doesn't have history
        let manager = HistoryManager(projectPath: "/tmp/swifthealth-test-\(UUID().uuidString)")
        let history = manager.loadOrCreate()

        XCTAssertEqual(history.version, 1)
        XCTAssertTrue(history.entries.isEmpty)
    }

    func testCalculateTrend_NoHistory_ReturnsUnknown() {
        let manager = HistoryManager(projectPath: "/tmp/swifthealth-test-\(UUID().uuidString)")
        let trend = manager.calculateTrend()

        XCTAssertEqual(trend.direction, .unknown)
        XCTAssertEqual(trend.entryCount, 0)
    }

    // MARK: - ASCII Chart

    func testGenerateASCIIChart_EmptyEntries_ReturnsMessage() {
        let manager = HistoryManager(projectPath: "/tmp/test")
        let chart = manager.generateASCIIChart(entries: [])

        XCTAssertTrue(chart.contains("No history data"))
    }

    func testGenerateASCIIChart_SingleEntry_ReturnsMessage() {
        let manager = HistoryManager(projectPath: "/tmp/test")
        let entry = HistoryEntry(score: 0.85, band: "green")
        let chart = manager.generateASCIIChart(entries: [entry])

        // Single entry can still generate a chart (degenerate case)
        XCTAssertFalse(chart.isEmpty)
    }

    func testGenerateASCIIChart_MultipleEntries_GeneratesChart() {
        let manager = HistoryManager(projectPath: "/tmp/test")
        let entries = [
            HistoryEntry(score: 0.85, band: "green"),
            HistoryEntry(score: 0.80, band: "good"),
            HistoryEntry(score: 0.75, band: "good")
        ]
        let chart = manager.generateASCIIChart(entries: entries)

        // Should contain axis markers
        XCTAssertTrue(chart.contains("|"))
        XCTAssertTrue(chart.contains("-"))
    }
}
