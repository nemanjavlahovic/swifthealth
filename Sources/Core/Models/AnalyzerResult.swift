import Foundation

/// The result returned by an analyzer after running
public struct AnalyzerResult: Codable, Equatable {
    /// The metrics produced by this analyzer
    public let metrics: [Metric]

    /// Diagnostic messages (warnings, missing tools, errors)
    public let diagnostics: [Diagnostic]

    public init(metrics: [Metric], diagnostics: [Diagnostic] = []) {
        self.metrics = metrics
        self.diagnostics = diagnostics
    }

    /// Convenience initializer for when an analyzer is unavailable
    public static func unavailable(reason: String) -> AnalyzerResult {
        AnalyzerResult(
            metrics: [],
            diagnostics: [
                Diagnostic(level: .warning, message: reason)
            ]
        )
    }
}

/// A diagnostic message from an analyzer
public struct Diagnostic: Codable, Equatable {
    /// Severity level
    public let level: DiagnosticLevel

    /// Human-readable message
    public let message: String

    /// Optional suggestion on how to fix
    public let hint: String?

    public init(level: DiagnosticLevel, message: String, hint: String? = nil) {
        self.level = level
        self.message = message
        self.hint = hint
    }
}

/// Diagnostic severity levels
public enum DiagnosticLevel: String, Codable, CaseIterable {
    case info
    case warning
    case error
}
