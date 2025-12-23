import Foundation

/// A single historical entry recording a health analysis run
public struct HistoryEntry: Codable, Equatable {
    /// When this analysis was run
    public let timestamp: Date

    /// The overall health score (0.0 to 1.0)
    public let score: Double

    /// The score band (green, yellow, orange, red)
    public let band: String

    /// Git commit hash at the time of analysis (if available)
    public let gitCommit: String?

    /// Git branch name at the time of analysis (if available)
    public let gitBranch: String?

    /// Individual metric scores for drill-down analysis
    public let metricScores: [String: Double]

    public init(
        timestamp: Date = Date(),
        score: Double,
        band: String,
        gitCommit: String? = nil,
        gitBranch: String? = nil,
        metricScores: [String: Double] = [:]
    ) {
        self.timestamp = timestamp
        self.score = score
        self.band = band
        self.gitCommit = gitCommit
        self.gitBranch = gitBranch
        self.metricScores = metricScores
    }

    /// Score as a percentage (0-100)
    public var scorePercent: Int {
        Int(score * 100)
    }
}

/// The complete history file structure
public struct HistoryFile: Codable, Equatable {
    /// Schema version for future migrations
    public let version: Int

    /// Absolute path to the project
    public let projectPath: String

    /// All recorded history entries (newest first)
    public var entries: [HistoryEntry]

    public init(
        version: Int = 1,
        projectPath: String,
        entries: [HistoryEntry] = []
    ) {
        self.version = version
        self.projectPath = projectPath
        self.entries = entries
    }

    /// Maximum number of entries to keep
    public static let maxEntries = 100
}

/// Trend direction based on recent history
public enum TrendDirection: String, Codable {
    case improving = "improving"
    case stable = "stable"
    case declining = "declining"
    case unknown = "unknown"

    public var emoji: String {
        switch self {
        case .improving: return "+"
        case .stable: return "~"
        case .declining: return "-"
        case .unknown: return "?"
        }
    }

    public var description: String {
        switch self {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        case .unknown: return "Not enough data"
        }
    }
}

/// Summary of historical trends
public struct TrendSummary: Equatable {
    /// Overall trend direction
    public let direction: TrendDirection

    /// Score change from last run
    public let deltaFromLast: Double?

    /// Score change from 7 days ago
    public let deltaFrom7Days: Double?

    /// Score change from 30 days ago
    public let deltaFrom30Days: Double?

    /// Number of entries in history
    public let entryCount: Int

    /// Average score over all history
    public let averageScore: Double?

    /// Best score ever recorded
    public let bestScore: Double?

    /// Worst score ever recorded
    public let worstScore: Double?

    public init(
        direction: TrendDirection = .unknown,
        deltaFromLast: Double? = nil,
        deltaFrom7Days: Double? = nil,
        deltaFrom30Days: Double? = nil,
        entryCount: Int = 0,
        averageScore: Double? = nil,
        bestScore: Double? = nil,
        worstScore: Double? = nil
    ) {
        self.direction = direction
        self.deltaFromLast = deltaFromLast
        self.deltaFrom7Days = deltaFrom7Days
        self.deltaFrom30Days = deltaFrom30Days
        self.entryCount = entryCount
        self.averageScore = averageScore
        self.bestScore = bestScore
        self.worstScore = worstScore
    }
}
