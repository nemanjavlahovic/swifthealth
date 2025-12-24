import Foundation

// MARK: - ProgressTracker Protocol

/// Protocol for tracking analysis progress
public protocol ProgressTracker {
    /// Called when starting analysis of a phase
    func startPhase(_ name: String, emoji: String)

    /// Called when a phase completes with results
    func completePhase(metrics: [Metric], diagnostics: [Diagnostic], verbose: Bool)

    /// Start an animated spinner for long operations
    func startSpinner(_ message: String) async

    /// Stop the spinner
    func stopSpinner(success: Bool, message: String)

    /// Print a status message
    func status(_ message: String)
}

// MARK: - Console Progress Tracker

/// Progress tracker that outputs to the console with colors and spinners
public final class ConsoleProgressTracker: ProgressTracker {
    private let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private var spinnerTask: Task<Void, Never>?
    private var isSpinning = false
    private var currentSpinnerMessage = ""

    public init() {}

    public func startPhase(_ name: String, emoji: String) {
        print("\(emoji) \(name)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    public func completePhase(metrics: [Metric], diagnostics: [Diagnostic], verbose: Bool) {
        for metric in metrics {
            printMetric(metric)
        }

        if !diagnostics.isEmpty {
            print()
            print("⚠️  Diagnostics:")
            for diagnostic in diagnostics {
                let icon = diagnosticIcon(diagnostic.level)
                print("  \(icon) \(diagnostic.message)")
                if let hint = diagnostic.hint {
                    print("     → \(hint)")
                }
            }
        }
        print()
    }

    public func startSpinner(_ message: String) async {
        isSpinning = true
        currentSpinnerMessage = message

        spinnerTask = Task { [weak self] in
            var frameIndex = 0
            while self?.isSpinning == true {
                guard let self = self else { break }
                let frame = self.spinnerFrames[frameIndex % self.spinnerFrames.count]
                print("\r\(frame) \(self.currentSpinnerMessage)", terminator: "")
                fflush(stdout)
                frameIndex += 1
                try? await Task.sleep(nanoseconds: 80_000_000) // 80ms
            }
        }
    }

    public func stopSpinner(success: Bool, message: String) {
        isSpinning = false
        spinnerTask?.cancel()
        spinnerTask = nil

        // Clear the line and print final status
        let icon = success ? "✓" : "✗"
        let padding = String(repeating: " ", count: max(0, currentSpinnerMessage.count - message.count + 5))
        print("\r\(icon) \(message)\(padding)")
    }

    public func status(_ message: String) {
        print(message)
    }

    // MARK: - Private Helpers

    private func printMetric(_ metric: Metric) {
        let valueStr: String
        switch metric.value {
        case .double(let val):
            valueStr = String(format: "%.2f", val)
        case .int(let val):
            valueStr = "\(val)"
        case .string(let val):
            valueStr = val
        case .percent(let val):
            valueStr = String(format: "%.1f%%", val * 100)
        case .duration(let val):
            valueStr = String(format: "%.2fs", val)
        }

        let unitStr = metric.unit.map { " \($0)" } ?? ""
        print("  \(metric.title): \(valueStr)\(unitStr)")
    }

    private func diagnosticIcon(_ level: DiagnosticLevel) -> String {
        switch level {
        case .error: return "❌"
        case .warning: return "⚠️"
        case .info: return "ℹ️"
        }
    }
}

// MARK: - Silent Progress Tracker

/// Progress tracker that produces no output (for JSON mode)
public final class SilentProgressTracker: ProgressTracker {
    public init() {}

    public func startPhase(_ name: String, emoji: String) {}
    public func completePhase(metrics: [Metric], diagnostics: [Diagnostic], verbose: Bool) {}
    public func startSpinner(_ message: String) async {}
    public func stopSpinner(success: Bool, message: String) {}
    public func status(_ message: String) {}
}

// MARK: - Progress Tracker Factory

/// Output format for progress tracker creation
public enum ProgressOutputMode {
    case silent  // For JSON/HTML output
    case console // For TTY output
}

public enum ProgressTrackerFactory {
    /// Creates the appropriate progress tracker based on output mode
    public static func create(for mode: ProgressOutputMode) -> ProgressTracker {
        switch mode {
        case .silent:
            return SilentProgressTracker()
        case .console:
            return ConsoleProgressTracker()
        }
    }
}
