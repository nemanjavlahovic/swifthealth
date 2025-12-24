import ArgumentParser
import Foundation
import Core

// Re-export Core's progress tracker types for convenience
public typealias ProgressTracker = Core.ProgressTracker
public typealias ConsoleProgressTracker = Core.ConsoleProgressTracker
public typealias SilentProgressTracker = Core.SilentProgressTracker

// MARK: - Output Format

/// Output format for the analysis results
public enum OutputFormat: String, ExpressibleByArgument, Sendable {
    case tty
    case json
    case html

    public init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }

    /// Convert to ProgressOutputMode for tracker creation
    public var progressOutputMode: ProgressOutputMode {
        switch self {
        case .json, .html:
            return .silent
        case .tty:
            return .console
        }
    }
}

// MARK: - Progress Tracker Factory Extension

extension ProgressTrackerFactory {
    /// Creates the appropriate progress tracker based on output format
    public static func create(for format: OutputFormat) -> Core.ProgressTracker {
        return create(for: format.progressOutputMode)
    }
}
