import XCTest
@testable import Core

/// Tests for ScoreEngine normalization functions
///
/// KEY LEARNING: Each normalizer transforms a raw metric value into a score from 0.0 to 1.0
/// - 1.0 = Perfect (healthy)
/// - 0.0 = Worst (unhealthy)
/// - 0.5 = Neutral/Unknown
final class ScoreEngineTests: XCTestCase {

    // MARK: - Setup

    /// The engine we're testing - created fresh for each test
    var engine: ScoreEngine!

    /// Default config with standard thresholds
    var defaultConfig: Config!

    override func setUp() {
        super.setUp()
        engine = ScoreEngine()
        defaultConfig = Config.default()
    }

    override func tearDown() {
        engine = nil
        defaultConfig = nil
        super.tearDown()
    }

    // MARK: - Helper Functions

    /// Creates a metric and calculates its normalized score
    /// This is a helper to reduce boilerplate in tests
    private func calculateScore(
        id: String,
        value: MetricValue,
        config: Config? = nil
    ) -> Double? {
        let metric = Metric(
            id: id,
            title: "Test Metric",
            category: .git,
            value: value
        )

        let result = engine.calculateScore(
            metrics: [metric],
            config: config ?? defaultConfig
        )

        // Return the score of the first (and only) metric
        return result.metrics.first?.score
    }

    // MARK: - Phase 1: Git Recency Normalizer Tests

    /// LEARNING POINT: Git recency measures "days since last commit"
    /// - Lower is better (recent commits = active project)
    /// - Uses threshold-based scoring with exponential decay for old projects

    func testGitRecency_ZeroDays_ReturnsPerfectScore() {
        // Arrange & Act
        let score = calculateScore(id: "git.recency", value: .double(0))

        // Assert
        XCTAssertEqual(score, 1.0, "0 days since commit should be perfect (1.0)")
    }

    func testGitRecency_WithinWarnThreshold_ReturnsPerfectScore() {
        // Default warn threshold is 7 days
        let score = calculateScore(id: "git.recency", value: .double(7))

        XCTAssertEqual(score, 1.0, "Within warn threshold should still be perfect")
    }

    func testGitRecency_AtFailThreshold_ReturnsHalfScore() {
        // Default fail threshold is 30 days
        // At exactly fail threshold, score should be ~0.5
        let score = calculateScore(id: "git.recency", value: .double(30))

        XCTAssertNotNil(score)
        XCTAssertEqual(score!, 0.5, accuracy: 0.01, "At fail threshold should be ~0.5")
    }

    func testGitRecency_BeyondFailThreshold_DecaysExponentially() {
        // 60 days = 30 days beyond fail threshold
        let score = calculateScore(id: "git.recency", value: .double(60))

        // Should be less than 0.5 but greater than 0
        XCTAssertNotNil(score)
        XCTAssertLessThan(score!, 0.5, "Beyond fail should be < 0.5")
        XCTAssertGreaterThan(score!, 0.0, "Should not hit zero yet")
    }

    // MARK: - Phase 1: Contributors Normalizer Tests

    /// LEARNING POINT: Contributors in last 30 days
    /// - More contributors = healthier project (not a solo abandoned project)
    /// - Uses step function: 0=0.0, 1=0.5, 2=0.7, 3=0.8, 4=0.9, 5+=1.0

    func testContributors_Zero_ReturnsZeroScore() {
        let score = calculateScore(id: "git.contributors30d", value: .int(0))

        XCTAssertEqual(score, 0.0, "Zero contributors = abandoned project")
    }

    func testContributors_One_ReturnsHalfScore() {
        let score = calculateScore(id: "git.contributors30d", value: .int(1))

        XCTAssertEqual(score, 0.5, "Solo contributor = 0.5 (not ideal but okay)")
    }

    func testContributors_FiveOrMore_ReturnsPerfectScore() {
        let scoreFive = calculateScore(id: "git.contributors30d", value: .int(5))
        let scoreTen = calculateScore(id: "git.contributors30d", value: .int(10))

        XCTAssertEqual(scoreFive, 1.0, "5 contributors = healthy team")
        XCTAssertEqual(scoreTen, 1.0, "10 contributors also = 1.0 (capped)")
    }

    // MARK: - Phase 1: Lint Warnings Normalizer Tests

    /// LEARNING POINT: Lint warnings count
    /// - Fewer warnings = better code quality
    /// - 0 warnings = perfect, then linear decay to threshold

    func testLintWarnings_Zero_ReturnsPerfectScore() {
        let score = calculateScore(id: "lint.warnings", value: .int(0))

        XCTAssertEqual(score, 1.0, "Zero warnings = perfect")
    }

    func testLintWarnings_BelowWarnThreshold_ReturnsHighScore() {
        // Default warn threshold is 50
        let score = calculateScore(id: "lint.warnings", value: .int(25))

        XCTAssertNotNil(score)
        XCTAssertGreaterThan(score!, 0.8, "Below warn threshold should be > 0.8")
        XCTAssertLessThan(score!, 1.0, "But not perfect")
    }

    func testLintWarnings_AtWarnThreshold_Returns0Point8() {
        // At exactly 50 warnings (default warn threshold)
        let score = calculateScore(id: "lint.warnings", value: .int(50))

        XCTAssertNotNil(score)
        XCTAssertEqual(score!, 0.8, accuracy: 0.01, "At warn threshold = 0.8")
    }

    // MARK: - Phase 1: Lint Errors Normalizer Tests

    /// LEARNING POINT: Lint errors are MORE severe than warnings
    /// - Even 1 error = steep penalty (0.7)
    /// - Errors indicate broken code, not just style issues

    func testLintErrors_Zero_ReturnsPerfectScore() {
        let score = calculateScore(id: "lint.errors", value: .int(0))

        XCTAssertEqual(score, 1.0, "Zero errors = perfect")
    }

    func testLintErrors_One_ReturnsSteepPenalty() {
        let score = calculateScore(id: "lint.errors", value: .int(1))

        XCTAssertEqual(score, 0.7, "Even 1 error = significant penalty")
    }

    // MARK: - Phase 1: Dead Code Normalizer Tests

    /// LEARNING POINT: Dead code count (unused declarations)
    /// - Less dead code = cleaner codebase
    /// - Similar pattern to lint warnings

    func testDeadCode_Zero_ReturnsPerfectScore() {
        let score = calculateScore(id: "deadcode.unused_count", value: .int(0))

        XCTAssertEqual(score, 1.0, "No dead code = perfect")
    }

    func testDeadCode_AtWarnThreshold_Returns0Point8() {
        // Default warn threshold is 10
        let score = calculateScore(id: "deadcode.unused_count", value: .int(10))

        XCTAssertNotNil(score)
        XCTAssertEqual(score!, 0.8, accuracy: 0.01, "At warn threshold = 0.8")
    }

    // MARK: - Phase 1: Unknown Metric Test

    /// LEARNING POINT: Unknown metrics get neutral score (0.5)
    /// - This is a safety net for future metrics
    /// - Better than crashing or returning 0

    func testUnknownMetric_ReturnsNeutralScore() {
        let score = calculateScore(id: "unknown.metric.id", value: .int(42))

        XCTAssertEqual(score, 0.5, "Unknown metrics default to neutral 0.5")
    }

    // MARK: - Phase 2: Edge Cases & Boundary Tests

    /// LEARNING POINT: Edge cases catch bugs that normal inputs miss
    /// - What happens with 0? Negative numbers? Huge numbers?
    /// - These are the inputs that often cause crashes in production

    func testGitRecency_VeryOldProject_NeverGoesNegative() {
        // 365 days = 1 year old, should still be >= 0
        let score = calculateScore(id: "git.recency", value: .double(365))

        XCTAssertNotNil(score)
        XCTAssertGreaterThanOrEqual(score!, 0.0, "Score should never go negative")
        XCTAssertLessThanOrEqual(score!, 1.0, "Score should never exceed 1.0")
    }

    func testGitRecency_ExtremeValue_StaysInBounds() {
        // 10 years old project
        let score = calculateScore(id: "git.recency", value: .double(3650))

        XCTAssertNotNil(score)
        XCTAssertGreaterThanOrEqual(score!, 0.0, "Even ancient projects stay >= 0")
        XCTAssertLessThanOrEqual(score!, 1.0, "Score capped at 1.0")
    }

    func testLintWarnings_ExtremeValue_StaysInBounds() {
        // 10,000 warnings - absurd but possible
        let score = calculateScore(id: "lint.warnings", value: .int(10000))

        XCTAssertNotNil(score)
        XCTAssertGreaterThanOrEqual(score!, 0.0, "Score stays >= 0")
        XCTAssertLessThanOrEqual(score!, 0.2, "Should be very low but not negative")
    }

    func testLintErrors_ExtremeValue_StaysInBounds() {
        // 1000 errors
        let score = calculateScore(id: "lint.errors", value: .int(1000))

        XCTAssertNotNil(score)
        XCTAssertGreaterThanOrEqual(score!, 0.0, "Score stays >= 0")
    }

    func testDeadCode_ExtremeValue_StaysInBounds() {
        // 500 unused declarations
        let score = calculateScore(id: "deadcode.unused_count", value: .int(500))

        XCTAssertNotNil(score)
        XCTAssertGreaterThanOrEqual(score!, 0.0, "Score stays >= 0")
    }

    func testContributors_LargeTeam_CapsAtPerfect() {
        // 100 contributors
        let score = calculateScore(id: "git.contributors30d", value: .int(100))

        XCTAssertEqual(score, 1.0, "Large teams still cap at 1.0")
    }

    // MARK: - Phase 2: Additional Normalizer Tests

    func testBranchCount_IdealRange_ReturnsPerfect() {
        let score = calculateScore(id: "git.branch.count", value: .int(5))

        XCTAssertEqual(score, 1.0, "2-10 branches is ideal")
    }

    func testBranchCount_TooFew_ReturnsLow() {
        let score = calculateScore(id: "git.branch.count", value: .int(1))

        XCTAssertEqual(score, 0.3, "Only 1 branch = not using branching strategy")
    }

    func testBranchCount_TooMany_ReturnsDegraded() {
        let score = calculateScore(id: "git.branch.count", value: .int(100))

        XCTAssertNotNil(score)
        XCTAssertLessThan(score!, 0.5, "100 branches = messy repo")
    }

    func testMergePercentage_LowMerges_ReturnsPerfect() {
        // Less than 10% merge commits = clean history
        let score = calculateScore(id: "git.merge.percentage", value: .percent(0.05))

        XCTAssertEqual(score, 1.0, "Low merge percentage = clean git history")
    }

    func testMergePercentage_HighMerges_ReturnsLow() {
        // 60% merge commits = messy history
        let score = calculateScore(id: "git.merge.percentage", value: .percent(0.60))

        XCTAssertEqual(score, 0.3, "High merge percentage = messy history")
    }

    func testCommentDensity_Ideal_ReturnsPerfect() {
        // 15% comments is in the ideal range (10-20%)
        let score = calculateScore(id: "code.comments.density", value: .percent(0.15))

        XCTAssertEqual(score, 1.0, "10-20% comments is ideal")
    }

    func testCommentDensity_TooFew_ReturnsLow() {
        // 2% comments = underdocumented
        let score = calculateScore(id: "code.comments.density", value: .percent(0.02))

        XCTAssertNotNil(score)
        XCTAssertLessThan(score!, 0.5, "Too few comments = underdocumented")
    }

    func testFileSize_Ideal_ReturnsPerfect() {
        // 100 lines avg is ideal (50-200)
        let score = calculateScore(id: "code.files.avgSize", value: .int(100))

        XCTAssertEqual(score, 1.0, "50-200 lines per file is ideal")
    }

    func testFileSize_TooLarge_ReturnsLow() {
        // 2000 lines avg = files too big
        let score = calculateScore(id: "code.files.avgSize", value: .int(2000))

        XCTAssertEqual(score, 0.2, "Huge files = hard to maintain")
    }

    func testLockfileAge_Fresh_ReturnsPerfect() {
        // 10 days old lockfile
        let score = calculateScore(id: "deps.spm.lockfileAge", value: .double(10))

        XCTAssertEqual(score, 1.0, "Fresh lockfile = good")
    }

    func testLockfileAge_Stale_ReturnsLow() {
        // 180 days old lockfile
        let score = calculateScore(id: "deps.spm.lockfileAge", value: .double(180))

        XCTAssertNotNil(score)
        XCTAssertLessThan(score!, 0.5, "Stale lockfile = outdated deps")
    }

    // MARK: - Phase 3: Weighted Score Calculation Tests

    /// LEARNING POINT: The overall health score is a weighted average
    /// - Each metric contributes based on its weight in config
    /// - Weights should sum to 1.0 (100%)

    func testCalculateScore_EmptyMetrics_ReturnsZero() {
        let result = engine.calculateScore(metrics: [], config: defaultConfig)

        XCTAssertEqual(result.score, 0.0, "No metrics = 0 score")
        XCTAssertEqual(result.band, .poor, "No metrics = poor band")
    }

    func testCalculateScore_AllPerfectMetrics_ReturnsPerfect() {
        let metrics = [
            Metric(id: "git.recency", title: "Recency", category: .git, value: .double(0)),
            Metric(id: "git.contributors30d", title: "Contributors", category: .git, value: .int(5)),
            Metric(id: "lint.warnings", title: "Warnings", category: .lint, value: .int(0)),
            Metric(id: "lint.errors", title: "Errors", category: .lint, value: .int(0)),
            Metric(id: "deps.outdated", title: "Outdated", category: .dependencies, value: .int(0)),
            Metric(id: "deadcode.unused_count", title: "Dead Code", category: .code, value: .int(0)),
        ]

        let result = engine.calculateScore(metrics: metrics, config: defaultConfig)

        XCTAssertEqual(result.score, 1.0, accuracy: 0.01, "All perfect metrics = perfect score")
        XCTAssertEqual(result.band, .excellent, "Perfect score = excellent band")
    }

    func testCalculateScore_MixedMetrics_ReturnsWeightedAverage() {
        let metrics = [
            Metric(id: "lint.warnings", title: "Warnings", category: .lint, value: .int(0)),    // 1.0
            Metric(id: "lint.errors", title: "Errors", category: .lint, value: .int(10)),       // ~0.2
        ]

        let result = engine.calculateScore(metrics: metrics, config: defaultConfig)

        // Score should be between 0.2 and 1.0, weighted by config
        XCTAssertGreaterThan(result.score, 0.2, "Mixed results = weighted average")
        XCTAssertLessThan(result.score, 1.0, "Not all perfect = not perfect score")
    }

    func testCalculateScore_EnrichesMetricsWithScores() {
        let metrics = [
            Metric(id: "lint.warnings", title: "Warnings", category: .lint, value: .int(0)),
        ]

        let result = engine.calculateScore(metrics: metrics, config: defaultConfig)

        XCTAssertEqual(result.metrics.count, 1, "Should return same number of metrics")
        XCTAssertNotNil(result.metrics.first?.score, "Metric should have score attached")
        XCTAssertEqual(result.metrics.first?.score, 1.0, "Score should be 1.0 for 0 warnings")
    }

    // MARK: - Phase 3: Score Band Tests

    func testScoreBand_90Plus_IsExcellent() {
        let band = ScoreBand.from(score: 0.95)
        XCTAssertEqual(band, .excellent)
    }

    func testScoreBand_70To89_IsGood() {
        let band = ScoreBand.from(score: 0.75)
        XCTAssertEqual(band, .good)
    }

    func testScoreBand_50To69_IsFair() {
        let band = ScoreBand.from(score: 0.55)
        XCTAssertEqual(band, .fair)
    }

    func testScoreBand_Below50_IsPoor() {
        let band = ScoreBand.from(score: 0.30)
        XCTAssertEqual(band, .poor)
    }

    // MARK: - Phase 3: Custom Config Tests

    func testCalculateScore_WithCustomThresholds_UsesCustomValues() {
        // Create config with very strict thresholds
        let strictThresholds = Thresholds(
            gitRecencyWarnDays: 1,    // Warn after just 1 day
            gitRecencyFailDays: 3     // Fail after 3 days
        )
        let strictConfig = Config(thresholds: strictThresholds)

        // 2 days with strict config should be in decay zone
        let score = calculateScore(id: "git.recency", value: .double(2), config: strictConfig)

        XCTAssertNotNil(score)
        XCTAssertLessThan(score!, 1.0, "2 days with strict config = not perfect")
    }
}
