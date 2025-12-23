import XCTest
@testable import Core

/// Tests for Config backward compatibility (JSON decoding with missing fields)
final class ConfigBackwardCompatibilityTests: XCTestCase {

    // MARK: - Weights Backward Compatibility

    func testWeights_DecodesWithMissingNewFields() throws {
        // Old config JSON without xcodeWarnings and appSize
        let oldConfigJSON = """
        {
            "git.recency": 0.1,
            "git.contributors30d": 0.1,
            "deps.outdated": 0.3,
            "lint.warnings": 0.2,
            "lint.errors": 0.1,
            "code.loc": 0.1,
            "deadcode.unused": 0.1
        }
        """

        let data = oldConfigJSON.data(using: .utf8)!
        let weights = try JSONDecoder().decode(Weights.self, from: data)

        // Old fields should be decoded
        XCTAssertEqual(weights.gitRecency, 0.1)
        XCTAssertEqual(weights.depsOutdated, 0.3)

        // New fields should have defaults
        XCTAssertEqual(weights.xcodeWarnings, Weights.defaultXcodeWarnings)
        XCTAssertEqual(weights.appSize, Weights.defaultAppSize)
        XCTAssertEqual(weights.buildAvgTime, Weights.defaultBuildAvgTime)
    }

    func testWeights_DecodesWithAllFields() throws {
        // Full config JSON with all fields
        let fullConfigJSON = """
        {
            "git.recency": 0.05,
            "git.contributors30d": 0.05,
            "deps.outdated": 0.3,
            "lint.warnings": 0.15,
            "lint.errors": 0.1,
            "code.loc": 0.1,
            "deadcode.unused": 0.1,
            "code.structure": 0.0,
            "test.coverage": 0.0,
            "build.avgTime": 0.05,
            "xcode.warnings": 0.05,
            "size.total": 0.05
        }
        """

        let data = fullConfigJSON.data(using: .utf8)!
        let weights = try JSONDecoder().decode(Weights.self, from: data)

        XCTAssertEqual(weights.xcodeWarnings, 0.05)
        XCTAssertEqual(weights.appSize, 0.05)
        XCTAssertEqual(weights.buildAvgTime, 0.05)
    }

    func testWeights_DecodesEmptyJSON() throws {
        // Completely empty weights - should use all defaults
        let emptyJSON = "{}"

        let data = emptyJSON.data(using: .utf8)!
        let weights = try JSONDecoder().decode(Weights.self, from: data)

        XCTAssertEqual(weights.gitRecency, Weights.defaultGitRecency)
        XCTAssertEqual(weights.xcodeWarnings, Weights.defaultXcodeWarnings)
        XCTAssertEqual(weights.appSize, Weights.defaultAppSize)
    }

    // MARK: - Thresholds Backward Compatibility

    func testThresholds_DecodesWithMissingNewFields() throws {
        // Old config JSON without xcode and size thresholds
        let oldConfigJSON = """
        {
            "git.recency.days.warn": 7,
            "git.recency.days.fail": 30,
            "deps.outdated.warnPct": 0.1,
            "deps.outdated.failPct": 0.3,
            "lint.warnings.warn": 50,
            "lint.warnings.fail": 200,
            "lint.errors.warn": 1,
            "lint.errors.fail": 10,
            "deadcode.unused.warn": 10,
            "deadcode.unused.fail": 50,
            "test.coverage.warn": 0.7,
            "test.coverage.fail": 0.5,
            "build.avgTime.warnSec": 45,
            "build.avgTime.failSec": 120
        }
        """

        let data = oldConfigJSON.data(using: .utf8)!
        let thresholds = try JSONDecoder().decode(Thresholds.self, from: data)

        // Old fields should be decoded
        XCTAssertEqual(thresholds.gitRecencyWarnDays, 7)
        XCTAssertEqual(thresholds.lintWarningsWarn, 50)

        // New fields should have defaults
        XCTAssertEqual(thresholds.xcodeWarningsWarn, Thresholds.defaultXcodeWarningsWarn)
        XCTAssertEqual(thresholds.xcodeWarningsFail, Thresholds.defaultXcodeWarningsFail)
        XCTAssertEqual(thresholds.appSizeWarnMB, Thresholds.defaultAppSizeWarnMB)
        XCTAssertEqual(thresholds.appSizeFailMB, Thresholds.defaultAppSizeFailMB)
    }

    func testThresholds_DecodesWithAllFields() throws {
        let fullConfigJSON = """
        {
            "git.recency.days.warn": 5,
            "git.recency.days.fail": 20,
            "deps.outdated.warnPct": 0.05,
            "deps.outdated.failPct": 0.2,
            "lint.warnings.warn": 25,
            "lint.warnings.fail": 100,
            "lint.errors.warn": 1,
            "lint.errors.fail": 5,
            "deadcode.unused.warn": 5,
            "deadcode.unused.fail": 25,
            "test.coverage.warn": 0.8,
            "test.coverage.fail": 0.6,
            "build.avgTime.warnSec": 30,
            "build.avgTime.failSec": 90,
            "xcode.warnings.warn": 10,
            "xcode.warnings.fail": 50,
            "size.total.warnMB": 50,
            "size.total.failMB": 100
        }
        """

        let data = fullConfigJSON.data(using: .utf8)!
        let thresholds = try JSONDecoder().decode(Thresholds.self, from: data)

        XCTAssertEqual(thresholds.xcodeWarningsWarn, 10)
        XCTAssertEqual(thresholds.xcodeWarningsFail, 50)
        XCTAssertEqual(thresholds.appSizeWarnMB, 50)
        XCTAssertEqual(thresholds.appSizeFailMB, 100)
    }

    // MARK: - Full Config Backward Compatibility

    func testConfig_OldFormatStillWorks() throws {
        // Simulate an old v1 config file format
        let oldConfigJSON = """
        {
            "version": 1,
            "weights": {
                "git.recency": 0.1,
                "git.contributors30d": 0.1,
                "deps.outdated": 0.3,
                "lint.warnings": 0.2,
                "lint.errors": 0.1,
                "code.loc": 0.1,
                "deadcode.unused": 0.1
            },
            "thresholds": {
                "git.recency.days.warn": 7,
                "git.recency.days.fail": 30,
                "deps.outdated.warnPct": 0.1,
                "deps.outdated.failPct": 0.3,
                "lint.warnings.warn": 50,
                "lint.warnings.fail": 200,
                "lint.errors.warn": 1,
                "lint.errors.fail": 10,
                "deadcode.unused.warn": 10,
                "deadcode.unused.fail": 50,
                "test.coverage.warn": 0.7,
                "test.coverage.fail": 0.5,
                "build.avgTime.warnSec": 45,
                "build.avgTime.failSec": 120
            },
            "ci": {
                "failUnder": 80
            },
            "plugins": []
        }
        """

        let data = oldConfigJSON.data(using: .utf8)!
        let config = try JSONDecoder().decode(Config.self, from: data)

        // Version should be correct
        XCTAssertEqual(config.version, 1)

        // Old weights preserved
        XCTAssertEqual(config.weights.gitRecency, 0.1)
        XCTAssertEqual(config.weights.depsOutdated, 0.3)

        // New weights have defaults
        XCTAssertEqual(config.weights.xcodeWarnings, 0.0)
        XCTAssertEqual(config.weights.appSize, 0.0)

        // Old thresholds preserved
        XCTAssertEqual(config.thresholds.gitRecencyWarnDays, 7)

        // New thresholds have defaults
        XCTAssertEqual(config.thresholds.xcodeWarningsWarn, 25)
        XCTAssertEqual(config.thresholds.appSizeWarnMB, 100)

        // CI settings preserved
        XCTAssertEqual(config.ci.failUnder, 80)
    }

    // MARK: - Default Static Constants

    func testWeights_DefaultConstants_AreCorrect() {
        XCTAssertEqual(Weights.defaultGitRecency, 0.05)
        XCTAssertEqual(Weights.defaultXcodeWarnings, 0.0)
        XCTAssertEqual(Weights.defaultAppSize, 0.0)
    }

    func testThresholds_DefaultConstants_AreCorrect() {
        XCTAssertEqual(Thresholds.defaultXcodeWarningsWarn, 25)
        XCTAssertEqual(Thresholds.defaultXcodeWarningsFail, 100)
        XCTAssertEqual(Thresholds.defaultAppSizeWarnMB, 100)
        XCTAssertEqual(Thresholds.defaultAppSizeFailMB, 200)
    }
}
