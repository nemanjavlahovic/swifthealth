import Foundation

/// Protocol that all analyzers must conform to
public protocol Analyzer {
    /// Unique identifier for this analyzer (e.g., "git", "deps", "lint")
    var id: String { get }

    /// Run the analysis and return results
    /// - Parameters:
    ///   - context: Information about the project being analyzed
    ///   - config: User configuration
    /// - Returns: Metrics and diagnostics from this analyzer
    func analyze(_ context: ProjectContext, _ config: Config) async -> AnalyzerResult
}

/// Context passed to all analyzers containing project information
public struct ProjectContext: Equatable {
    /// Absolute path to the project root
    public let rootPath: String

    /// Detected project types
    public let projectTypes: [ProjectType]

    /// Whether to operate in offline mode (no network calls)
    public let offline: Bool

    /// Optional paths to specific artifacts
    public let artifacts: Artifacts

    public init(
        rootPath: String,
        projectTypes: [ProjectType] = [],
        offline: Bool = false,
        artifacts: Artifacts = Artifacts()
    ) {
        self.rootPath = rootPath
        self.projectTypes = projectTypes
        self.offline = offline
        self.artifacts = artifacts
    }

    /// Check if a specific project type was detected
    public func has(_ type: ProjectType) -> Bool {
        projectTypes.contains(type)
    }
}

/// Optional artifact paths that analyzers might use
public struct Artifacts: Equatable {
    /// Path to DerivedData (for Xcode projects)
    public let derivedDataPath: String?

    /// Path to .xcresult bundle (for test coverage)
    public let xcresultPath: String?

    /// Path to build logs
    public let buildLogsPath: String?

    public init(
        derivedDataPath: String? = nil,
        xcresultPath: String? = nil,
        buildLogsPath: String? = nil
    ) {
        self.derivedDataPath = derivedDataPath
        self.xcresultPath = xcresultPath
        self.buildLogsPath = buildLogsPath
    }
}
