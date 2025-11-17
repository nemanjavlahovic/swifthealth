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
public struct Weights: Codable, Equatable {
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
    }

    public init(
        gitRecency: Double = 0.05,
        gitContributors: Double = 0.05,
        depsOutdated: Double = 0.35,
        lintWarnings: Double = 0.15,
        lintErrors: Double = 0.15,
        codeLOC: Double = 0.10,
        deadCodeUnused: Double = 0.15,
        codeStructure: Double = 0.00,  // Not yet implemented
        testCoverage: Double = 0.00,   // Not yet implemented
        buildAvgTime: Double = 0.00    // Not yet implemented
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
    }

    /// Calculate total weight (should be <= 1.0)
    public var total: Double {
        gitRecency + gitContributors + depsOutdated +
        lintWarnings + lintErrors + codeLOC + deadCodeUnused +
        codeStructure + testCoverage + buildAvgTime
    }
}

/// Thresholds for scoring metrics
public struct Thresholds: Codable, Equatable {
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
    }

    public init(
        gitRecencyWarnDays: Int = 7,
        gitRecencyFailDays: Int = 30,
        depsOutdatedWarnPct: Double = 0.10,
        depsOutdatedFailPct: Double = 0.30,
        lintWarningsWarn: Int = 50,
        lintWarningsFail: Int = 200,
        lintErrorsWarn: Int = 1,
        lintErrorsFail: Int = 10,
        deadCodeUnusedWarn: Int = 10,
        deadCodeUnusedFail: Int = 50,
        testCoverageWarn: Double = 0.70,
        testCoverageFail: Double = 0.50,
        buildAvgTimeWarnSec: Int = 45,
        buildAvgTimeFailSec: Int = 120
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
