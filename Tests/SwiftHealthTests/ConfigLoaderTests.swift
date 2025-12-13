import XCTest
@testable import Core

/// Tests for ConfigLoader validation and loading logic
final class ConfigLoaderTests: XCTestCase {

    // MARK: - Default Config Tests

    func testDefaultConfig_HasValidWeights() {
        let config = Config.default()

        // Weights should sum to 1.0 (allowing for floating point imprecision)
        XCTAssertEqual(config.weights.total, 1.0, accuracy: 0.001, "Default weights should sum to 1.0")
    }

    func testDefaultConfig_HasReasonableThresholds() {
        let config = Config.default()
        let thresholds = config.thresholds

        // Warn should always be less than fail
        XCTAssertLessThan(thresholds.gitRecencyWarnDays, thresholds.gitRecencyFailDays)
        XCTAssertLessThan(thresholds.lintWarningsWarn, thresholds.lintWarningsFail)
        XCTAssertLessThan(thresholds.lintErrorsWarn, thresholds.lintErrorsFail)
        XCTAssertLessThan(thresholds.deadCodeUnusedWarn, thresholds.deadCodeUnusedFail)
    }

    func testDefaultConfig_HasVersion1() {
        let config = Config.default()

        XCTAssertEqual(config.version, 1, "Default config should be version 1")
    }

    // MARK: - Validation Tests

    func testValidate_ValidConfig_DoesNotThrow() {
        let config = Config.default()

        XCTAssertNoThrow(try ConfigLoader.validate(config), "Valid config should not throw")
    }

    func testValidate_WeightsExceed1_Throws() {
        // Create config with weights that sum to more than 1.0
        let invalidWeights = Weights(
            gitRecency: 0.5,
            gitContributors: 0.5,
            depsOutdated: 0.5,  // This makes total > 1.0
            lintWarnings: 0.0,
            lintErrors: 0.0,
            codeLOC: 0.0,
            deadCodeUnused: 0.0
        )
        let config = Config(weights: invalidWeights)

        XCTAssertThrowsError(try ConfigLoader.validate(config)) { error in
            guard let configError = error as? ConfigError else {
                XCTFail("Expected ConfigError")
                return
            }
            XCTAssertTrue(configError.description.contains("Weights"), "Error should mention weights")
        }
    }

    func testValidate_InvalidVersion_Throws() {
        let config = Config(version: 99)  // Unsupported version

        XCTAssertThrowsError(try ConfigLoader.validate(config)) { error in
            guard let configError = error as? ConfigError else {
                XCTFail("Expected ConfigError")
                return
            }
            XCTAssertTrue(configError.description.contains("version"), "Error should mention version")
        }
    }

    func testValidate_WarnGreaterThanFail_Throws() {
        // Invalid: warn threshold > fail threshold
        let invalidThresholds = Thresholds(
            gitRecencyWarnDays: 30,  // Warn at 30 days
            gitRecencyFailDays: 7    // But fail at 7 days (makes no sense)
        )
        let config = Config(thresholds: invalidThresholds)

        XCTAssertThrowsError(try ConfigLoader.validate(config)) { error in
            guard let configError = error as? ConfigError else {
                XCTFail("Expected ConfigError")
                return
            }
            XCTAssertTrue(configError.description.contains("git.recency"), "Error should mention the threshold")
        }
    }

    func testValidate_CIFailUnderOutOfRange_Throws() {
        let invalidCI = CISettings(failUnder: 150)  // Max is 100
        let config = Config(ci: invalidCI)

        XCTAssertThrowsError(try ConfigLoader.validate(config)) { error in
            guard let configError = error as? ConfigError else {
                XCTFail("Expected ConfigError")
                return
            }
            XCTAssertTrue(configError.description.contains("failUnder"), "Error should mention failUnder")
        }
    }

    // MARK: - Load Tests (File System)

    func testLoad_NonExistentFile_ReturnsDefault() throws {
        // Loading from a directory without a config file should return defaults
        let config = try ConfigLoader.load(fromDirectory: "/tmp/nonexistent-swifthealth-test-dir")

        XCTAssertEqual(config.version, 1, "Should return default config")
        XCTAssertEqual(config.weights.total, 1.0, accuracy: 0.001, "Should have default weights")
    }

    // MARK: - Weights Tests

    func testWeights_Total_CalculatesCorrectly() {
        let weights = Weights(
            gitRecency: 0.1,
            gitContributors: 0.1,
            depsOutdated: 0.2,
            lintWarnings: 0.2,
            lintErrors: 0.2,
            codeLOC: 0.1,
            deadCodeUnused: 0.1
        )

        XCTAssertEqual(weights.total, 1.0, accuracy: 0.001, "Total should be sum of all weights")
    }

    func testWeights_AllZero_TotalIsZero() {
        let weights = Weights(
            gitRecency: 0,
            gitContributors: 0,
            depsOutdated: 0,
            lintWarnings: 0,
            lintErrors: 0,
            codeLOC: 0,
            deadCodeUnused: 0
        )

        XCTAssertEqual(weights.total, 0.0, "All zero weights = 0 total")
    }

    // MARK: - Config Equatable Tests

    func testConfig_Equatable_SameConfigs() {
        let config1 = Config.default()
        let config2 = Config.default()

        XCTAssertEqual(config1, config2, "Two default configs should be equal")
    }

    func testConfig_Equatable_DifferentConfigs() {
        let config1 = Config.default()
        let config2 = Config(version: 1, ci: CISettings(failUnder: 50))

        XCTAssertNotEqual(config1, config2, "Different configs should not be equal")
    }
}
