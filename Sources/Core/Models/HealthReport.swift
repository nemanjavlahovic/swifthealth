import Foundation

/// The complete health report for a project
public struct HealthReport: Codable, Equatable {
    /// Tool metadata
    public let tool: ToolInfo

    /// Project information
    public let project: ProjectInfo

    /// All metrics from all analyzers
    public let metrics: [Metric]

    /// Overall health score [0.0, 1.0]
    public let score: Double

    /// Score band (for color coding)
    public let band: ScoreBand

    /// All diagnostic messages
    public let diagnostics: [Diagnostic]

    /// When this report was generated
    public let timestamp: Date

    public init(
        tool: ToolInfo,
        project: ProjectInfo,
        metrics: [Metric],
        score: Double,
        band: ScoreBand,
        diagnostics: [Diagnostic],
        timestamp: Date = Date()
    ) {
        self.tool = tool
        self.project = project
        self.metrics = metrics
        self.score = score
        self.band = band
        self.diagnostics = diagnostics
        self.timestamp = timestamp
    }
}

/// Information about the swifthealth tool itself
public struct ToolInfo: Codable, Equatable {
    public let name: String
    public let version: String

    public init(name: String = "swifthealth", version: String) {
        self.name = name
        self.version = version
    }
}

/// Information about the analyzed project
public struct ProjectInfo: Codable, Equatable {
    /// Absolute path to the project root
    public let root: String

    /// Detected project types
    public let detected: [ProjectType]

    public init(root: String, detected: [ProjectType]) {
        self.root = root
        self.detected = detected
    }
}

/// Types of projects we can detect
public enum ProjectType: String, Codable, CaseIterable {
    case spm = "spm"
    case xcodeproj = "xcodeproj"
    case xcworkspace = "xcworkspace"
    case git = "git"
    case cocoapods = "cocoapods"
    case carthage = "carthage"
}

/// Health score bands (for color coding and thresholds)
public enum ScoreBand: String, Codable, CaseIterable {
    case excellent = "green"    // >= 90
    case good = "yellow"        // >= 75
    case poor = "red"           // < 75

    /// Determine band from a score
    public static func from(score: Double) -> ScoreBand {
        if score >= 0.90 {
            return .excellent
        } else if score >= 0.75 {
            return .good
        } else {
            return .poor
        }
    }

    /// Human-readable label
    public var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .poor: return "Needs Improvement"
        }
    }

    /// Emoji representation
    public var emoji: String {
        switch self {
        case .excellent: return "🟢"
        case .good: return "🟡"
        case .poor: return "🔴"
        }
    }
}
