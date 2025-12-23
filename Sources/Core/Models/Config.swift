import Foundation

/// User configuration for SwiftHealth (loaded from .swifthealthrc.json)
public struct Config: Codable, Equatable {
    /// Config schema version
    public let version: Int

    /// Weights for each metric (must sum to <= 1.0)
    public let weights: Weights

    /// Thresholds for scoring
    public let thresholds: Thresholds

    /// CI-specific settings
    public let ci: CISettings

    /// Plugin paths (v1.0 feature)
    /// periphery:ignore - Reserved for future plugin system
    public let plugins: [String]

    public init(
        version: Int = 1,
        weights: Weights = Weights(),
        thresholds: Thresholds = Thresholds(),
        ci: CISettings = CISettings(),
        plugins: [String] = []
    ) {
        self.version = version
        self.weights = weights
        self.thresholds = thresholds
        self.ci = ci
        self.plugins = plugins
    }

    /// Create default configuration
    public static func `default`() -> Config {
        Config()
    }
}

/// Metric weights (how important each metric is in the overall score)
public struct Weights: Equatable {
    public let gitRecency: Double
    public let gitContributors: Double
    public let depsOutdated: Double
    public let lintWarnings: Double
    public let lintErrors: Double
    public let codeLOC: Double
    public let deadCodeUnused: Double
    public let codeStructure: Double
    public let testCoverage: Double
    public let buildAvgTime: Double
    public let xcodeWarnings: Double
    public let appSize: Double

    // Default values as static constants for reuse
    public static let defaultGitRecency: Double = 0.05
    public static let defaultGitContributors: Double = 0.05
    public static let defaultDepsOutdated: Double = 0.35
    public static let defaultLintWarnings: Double = 0.15
    public static let defaultLintErrors: Double = 0.15
    public static let defaultCodeLOC: Double = 0.10
    public static let defaultDeadCodeUnused: Double = 0.15
    public static let defaultCodeStructure: Double = 0.00
    public static let defaultTestCoverage: Double = 0.00
    public static let defaultBuildAvgTime: Double = 0.00
    public static let defaultXcodeWarnings: Double = 0.00
    public static let defaultAppSize: Double = 0.00

    enum CodingKeys: String, CodingKey {
        case gitRecency = "git.recency"
        case gitContributors = "git.contributors30d"
        case depsOutdated = "deps.outdated"
        case lintWarnings = "lint.warnings"
        case lintErrors = "lint.errors"
        case codeLOC = "code.loc"
        case deadCodeUnused = "deadcode.unused"
        case codeStructure = "code.structure"
        case testCoverage = "test.coverage"
        case buildAvgTime = "build.avgTime"
        case xcodeWarnings = "xcode.warnings"
        case appSize = "size.total"
    }

    public init(
        gitRecency: Double = defaultGitRecency,
        gitContributors: Double = defaultGitContributors,
        depsOutdated: Double = defaultDepsOutdated,
        lintWarnings: Double = defaultLintWarnings,
        lintErrors: Double = defaultLintErrors,
        codeLOC: Double = defaultCodeLOC,
        deadCodeUnused: Double = defaultDeadCodeUnused,
        codeStructure: Double = defaultCodeStructure,
        testCoverage: Double = defaultTestCoverage,
        buildAvgTime: Double = defaultBuildAvgTime,
        xcodeWarnings: Double = defaultXcodeWarnings,
        appSize: Double = defaultAppSize
    ) {
        self.gitRecency = gitRecency
        self.gitContributors = gitContributors
        self.depsOutdated = depsOutdated
        self.lintWarnings = lintWarnings
        self.lintErrors = lintErrors
        self.codeLOC = codeLOC
        self.deadCodeUnused = deadCodeUnused
        self.codeStructure = codeStructure
        self.testCoverage = testCoverage
        self.buildAvgTime = buildAvgTime
        self.xcodeWarnings = xcodeWarnings
        self.appSize = appSize
    }

    /// Calculate total weight (should be <= 1.0)
    public var total: Double {
        gitRecency + gitContributors + depsOutdated +
        lintWarnings + lintErrors + codeLOC + deadCodeUnused +
        codeStructure + testCoverage + buildAvgTime +
        xcodeWarnings + appSize
    }
}

// Custom Codable to handle missing fields gracefully (backward compatibility)
extension Weights: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.gitRecency = try container.decodeIfPresent(Double.self, forKey: .gitRecency) ?? Self.defaultGitRecency
        self.gitContributors = try container.decodeIfPresent(Double.self, forKey: .gitContributors) ?? Self.defaultGitContributors
        self.depsOutdated = try container.decodeIfPresent(Double.self, forKey: .depsOutdated) ?? Self.defaultDepsOutdated
        self.lintWarnings = try container.decodeIfPresent(Double.self, forKey: .lintWarnings) ?? Self.defaultLintWarnings
        self.lintErrors = try container.decodeIfPresent(Double.self, forKey: .lintErrors) ?? Self.defaultLintErrors
        self.codeLOC = try container.decodeIfPresent(Double.self, forKey: .codeLOC) ?? Self.defaultCodeLOC
        self.deadCodeUnused = try container.decodeIfPresent(Double.self, forKey: .deadCodeUnused) ?? Self.defaultDeadCodeUnused
        self.codeStructure = try container.decodeIfPresent(Double.self, forKey: .codeStructure) ?? Self.defaultCodeStructure
        self.testCoverage = try container.decodeIfPresent(Double.self, forKey: .testCoverage) ?? Self.defaultTestCoverage
        self.buildAvgTime = try container.decodeIfPresent(Double.self, forKey: .buildAvgTime) ?? Self.defaultBuildAvgTime
        self.xcodeWarnings = try container.decodeIfPresent(Double.self, forKey: .xcodeWarnings) ?? Self.defaultXcodeWarnings
        self.appSize = try container.decodeIfPresent(Double.self, forKey: .appSize) ?? Self.defaultAppSize
    }
}

/// Thresholds for scoring metrics
public struct Thresholds: Equatable {
    // Git thresholds
    public let gitRecencyWarnDays: Int
    public let gitRecencyFailDays: Int

    // Dependency thresholds
    public let depsOutdatedWarnPct: Double
    public let depsOutdatedFailPct: Double

    // Lint thresholds
    public let lintWarningsWarn: Int
    public let lintWarningsFail: Int
    public let lintErrorsWarn: Int
    public let lintErrorsFail: Int

    // Dead code thresholds
    public let deadCodeUnusedWarn: Int
    public let deadCodeUnusedFail: Int

    // Test coverage thresholds
    public let testCoverageWarn: Double
    public let testCoverageFail: Double

    // Build time thresholds
    public let buildAvgTimeWarnSec: Int
    public let buildAvgTimeFailSec: Int

    // Xcode warnings thresholds
    public let xcodeWarningsWarn: Int
    public let xcodeWarningsFail: Int

    // App size thresholds (in MB)
    public let appSizeWarnMB: Int
    public let appSizeFailMB: Int

    // Default values
    public static let defaultGitRecencyWarnDays = 7
    public static let defaultGitRecencyFailDays = 30
    public static let defaultDepsOutdatedWarnPct = 0.10
    public static let defaultDepsOutdatedFailPct = 0.30
    public static let defaultLintWarningsWarn = 50
    public static let defaultLintWarningsFail = 200
    public static let defaultLintErrorsWarn = 1
    public static let defaultLintErrorsFail = 10
    public static let defaultDeadCodeUnusedWarn = 10
    public static let defaultDeadCodeUnusedFail = 50
    public static let defaultTestCoverageWarn = 0.70
    public static let defaultTestCoverageFail = 0.50
    public static let defaultBuildAvgTimeWarnSec = 45
    public static let defaultBuildAvgTimeFailSec = 120
    public static let defaultXcodeWarningsWarn = 25
    public static let defaultXcodeWarningsFail = 100
    public static let defaultAppSizeWarnMB = 100
    public static let defaultAppSizeFailMB = 200

    enum CodingKeys: String, CodingKey {
        case gitRecencyWarnDays = "git.recency.days.warn"
        case gitRecencyFailDays = "git.recency.days.fail"
        case depsOutdatedWarnPct = "deps.outdated.warnPct"
        case depsOutdatedFailPct = "deps.outdated.failPct"
        case lintWarningsWarn = "lint.warnings.warn"
        case lintWarningsFail = "lint.warnings.fail"
        case lintErrorsWarn = "lint.errors.warn"
        case lintErrorsFail = "lint.errors.fail"
        case deadCodeUnusedWarn = "deadcode.unused.warn"
        case deadCodeUnusedFail = "deadcode.unused.fail"
        case testCoverageWarn = "test.coverage.warn"
        case testCoverageFail = "test.coverage.fail"
        case buildAvgTimeWarnSec = "build.avgTime.warnSec"
        case buildAvgTimeFailSec = "build.avgTime.failSec"
        case xcodeWarningsWarn = "xcode.warnings.warn"
        case xcodeWarningsFail = "xcode.warnings.fail"
        case appSizeWarnMB = "size.total.warnMB"
        case appSizeFailMB = "size.total.failMB"
    }

    public init(
        gitRecencyWarnDays: Int = defaultGitRecencyWarnDays,
        gitRecencyFailDays: Int = defaultGitRecencyFailDays,
        depsOutdatedWarnPct: Double = defaultDepsOutdatedWarnPct,
        depsOutdatedFailPct: Double = defaultDepsOutdatedFailPct,
        lintWarningsWarn: Int = defaultLintWarningsWarn,
        lintWarningsFail: Int = defaultLintWarningsFail,
        lintErrorsWarn: Int = defaultLintErrorsWarn,
        lintErrorsFail: Int = defaultLintErrorsFail,
        deadCodeUnusedWarn: Int = defaultDeadCodeUnusedWarn,
        deadCodeUnusedFail: Int = defaultDeadCodeUnusedFail,
        testCoverageWarn: Double = defaultTestCoverageWarn,
        testCoverageFail: Double = defaultTestCoverageFail,
        buildAvgTimeWarnSec: Int = defaultBuildAvgTimeWarnSec,
        buildAvgTimeFailSec: Int = defaultBuildAvgTimeFailSec,
        xcodeWarningsWarn: Int = defaultXcodeWarningsWarn,
        xcodeWarningsFail: Int = defaultXcodeWarningsFail,
        appSizeWarnMB: Int = defaultAppSizeWarnMB,
        appSizeFailMB: Int = defaultAppSizeFailMB
    ) {
        self.gitRecencyWarnDays = gitRecencyWarnDays
        self.gitRecencyFailDays = gitRecencyFailDays
        self.depsOutdatedWarnPct = depsOutdatedWarnPct
        self.depsOutdatedFailPct = depsOutdatedFailPct
        self.lintWarningsWarn = lintWarningsWarn
        self.lintWarningsFail = lintWarningsFail
        self.lintErrorsWarn = lintErrorsWarn
        self.lintErrorsFail = lintErrorsFail
        self.deadCodeUnusedWarn = deadCodeUnusedWarn
        self.deadCodeUnusedFail = deadCodeUnusedFail
        self.testCoverageWarn = testCoverageWarn
        self.testCoverageFail = testCoverageFail
        self.buildAvgTimeWarnSec = buildAvgTimeWarnSec
        self.buildAvgTimeFailSec = buildAvgTimeFailSec
        self.xcodeWarningsWarn = xcodeWarningsWarn
        self.xcodeWarningsFail = xcodeWarningsFail
        self.appSizeWarnMB = appSizeWarnMB
        self.appSizeFailMB = appSizeFailMB
    }
}

// Custom Codable for backward compatibility
extension Thresholds: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.gitRecencyWarnDays = try container.decodeIfPresent(Int.self, forKey: .gitRecencyWarnDays) ?? Self.defaultGitRecencyWarnDays
        self.gitRecencyFailDays = try container.decodeIfPresent(Int.self, forKey: .gitRecencyFailDays) ?? Self.defaultGitRecencyFailDays
        self.depsOutdatedWarnPct = try container.decodeIfPresent(Double.self, forKey: .depsOutdatedWarnPct) ?? Self.defaultDepsOutdatedWarnPct
        self.depsOutdatedFailPct = try container.decodeIfPresent(Double.self, forKey: .depsOutdatedFailPct) ?? Self.defaultDepsOutdatedFailPct
        self.lintWarningsWarn = try container.decodeIfPresent(Int.self, forKey: .lintWarningsWarn) ?? Self.defaultLintWarningsWarn
        self.lintWarningsFail = try container.decodeIfPresent(Int.self, forKey: .lintWarningsFail) ?? Self.defaultLintWarningsFail
        self.lintErrorsWarn = try container.decodeIfPresent(Int.self, forKey: .lintErrorsWarn) ?? Self.defaultLintErrorsWarn
        self.lintErrorsFail = try container.decodeIfPresent(Int.self, forKey: .lintErrorsFail) ?? Self.defaultLintErrorsFail
        self.deadCodeUnusedWarn = try container.decodeIfPresent(Int.self, forKey: .deadCodeUnusedWarn) ?? Self.defaultDeadCodeUnusedWarn
        self.deadCodeUnusedFail = try container.decodeIfPresent(Int.self, forKey: .deadCodeUnusedFail) ?? Self.defaultDeadCodeUnusedFail
        self.testCoverageWarn = try container.decodeIfPresent(Double.self, forKey: .testCoverageWarn) ?? Self.defaultTestCoverageWarn
        self.testCoverageFail = try container.decodeIfPresent(Double.self, forKey: .testCoverageFail) ?? Self.defaultTestCoverageFail
        self.buildAvgTimeWarnSec = try container.decodeIfPresent(Int.self, forKey: .buildAvgTimeWarnSec) ?? Self.defaultBuildAvgTimeWarnSec
        self.buildAvgTimeFailSec = try container.decodeIfPresent(Int.self, forKey: .buildAvgTimeFailSec) ?? Self.defaultBuildAvgTimeFailSec
        self.xcodeWarningsWarn = try container.decodeIfPresent(Int.self, forKey: .xcodeWarningsWarn) ?? Self.defaultXcodeWarningsWarn
        self.xcodeWarningsFail = try container.decodeIfPresent(Int.self, forKey: .xcodeWarningsFail) ?? Self.defaultXcodeWarningsFail
        self.appSizeWarnMB = try container.decodeIfPresent(Int.self, forKey: .appSizeWarnMB) ?? Self.defaultAppSizeWarnMB
        self.appSizeFailMB = try container.decodeIfPresent(Int.self, forKey: .appSizeFailMB) ?? Self.defaultAppSizeFailMB
    }
}

/// CI-specific configuration
public struct CISettings: Codable, Equatable {
    /// Minimum score to pass in CI (0-100)
    public let failUnder: Int

    public init(failUnder: Int = 80) {
        self.failUnder = failUnder
    }
}
