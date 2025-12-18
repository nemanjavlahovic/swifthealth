import XCTest
@testable import SwiftHealthCLI
@testable import Core

/// Tests for ProgressTracker implementations
final class ProgressTrackerTests: XCTestCase {

    // MARK: - Mock Progress Tracker for Testing

    /// A mock progress tracker that records all method calls for verification
    final class MockProgressTracker: ProgressTracker {
        var startPhaseCalls: [(name: String, emoji: String)] = []
        var completePhaseCalls: [(metrics: [Metric], diagnostics: [Diagnostic], verbose: Bool)] = []
        var startSpinnerCalls: [String] = []
        var stopSpinnerCalls: [(success: Bool, message: String)] = []
        var statusCalls: [String] = []

        func startPhase(_ name: String, emoji: String) {
            startPhaseCalls.append((name: name, emoji: emoji))
        }

        func completePhase(metrics: [Metric], diagnostics: [Diagnostic], verbose: Bool) {
            completePhaseCalls.append((metrics: metrics, diagnostics: diagnostics, verbose: verbose))
        }

        func startSpinner(_ message: String) async {
            startSpinnerCalls.append(message)
        }

        func stopSpinner(success: Bool, message: String) {
            stopSpinnerCalls.append((success: success, message: message))
        }

        func status(_ message: String) {
            statusCalls.append(message)
        }
    }

    // MARK: - SilentProgressTracker Tests

    func testSilentProgressTracker_doesNothing() async {
        // SilentProgressTracker should not crash and should do nothing
        let tracker = SilentProgressTracker()

        // None of these should crash or produce any side effects
        tracker.startPhase("Test", emoji: "🧪")
        tracker.completePhase(metrics: [], diagnostics: [], verbose: false)
        await tracker.startSpinner("Loading...")
        tracker.stopSpinner(success: true, message: "Done")
        tracker.status("Status message")

        // If we get here without crashing, the test passes
        XCTAssertTrue(true)
    }

    func testSilentProgressTracker_handlesMetricsAndDiagnostics() {
        let tracker = SilentProgressTracker()

        let metrics = [
            Metric(
                id: "test.metric",
                title: "Test Metric",
                category: .test,
                value: .int(42)
            )
        ]

        let diagnostics = [
            Diagnostic(level: .warning, message: "Test warning", hint: "Fix it")
        ]

        // Should not crash with real data
        tracker.completePhase(metrics: metrics, diagnostics: diagnostics, verbose: true)
        XCTAssertTrue(true)
    }

    // MARK: - ConsoleProgressTracker Tests

    func testConsoleProgressTracker_initialization() {
        let tracker = ConsoleProgressTracker()
        XCTAssertNotNil(tracker)
    }

    func testConsoleProgressTracker_startPhase_doesNotCrash() {
        let tracker = ConsoleProgressTracker()
        tracker.startPhase("Git Analysis", emoji: "📊")
        XCTAssertTrue(true)
    }

    func testConsoleProgressTracker_completePhase_withEmptyData() {
        let tracker = ConsoleProgressTracker()
        tracker.completePhase(metrics: [], diagnostics: [], verbose: false)
        XCTAssertTrue(true)
    }

    func testConsoleProgressTracker_completePhase_withMetrics() {
        let tracker = ConsoleProgressTracker()

        let metrics = [
            Metric(id: "test.int", title: "Integer Metric", category: .test, value: .int(42)),
            Metric(id: "test.double", title: "Double Metric", category: .test, value: .double(3.14)),
            Metric(id: "test.percent", title: "Percent Metric", category: .test, value: .percent(0.75)),
            Metric(id: "test.string", title: "String Metric", category: .test, value: .string("hello")),
            Metric(id: "test.duration", title: "Duration Metric", category: .test, value: .duration(45.5))
        ]

        tracker.completePhase(metrics: metrics, diagnostics: [], verbose: false)
        XCTAssertTrue(true)
    }

    func testConsoleProgressTracker_completePhase_withDiagnostics() {
        let tracker = ConsoleProgressTracker()

        let diagnostics = [
            Diagnostic(level: .info, message: "Info message", hint: nil),
            Diagnostic(level: .warning, message: "Warning message", hint: "Fix this"),
            Diagnostic(level: .error, message: "Error message", hint: "Critical fix needed")
        ]

        tracker.completePhase(metrics: [], diagnostics: diagnostics, verbose: true)
        XCTAssertTrue(true)
    }

    func testConsoleProgressTracker_spinner_startAndStop() async {
        let tracker = ConsoleProgressTracker()

        await tracker.startSpinner("Processing...")

        // Small delay to let spinner run
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        tracker.stopSpinner(success: true, message: "Complete")
        XCTAssertTrue(true)
    }

    func testConsoleProgressTracker_spinner_stopWithFailure() async {
        let tracker = ConsoleProgressTracker()

        await tracker.startSpinner("Processing...")
        tracker.stopSpinner(success: false, message: "Failed")
        XCTAssertTrue(true)
    }

    func testConsoleProgressTracker_status() {
        let tracker = ConsoleProgressTracker()
        tracker.status("Status update message")
        XCTAssertTrue(true)
    }

    // MARK: - ProgressTrackerFactory Tests

    func testProgressTrackerFactory_createsTTYTracker() {
        let tracker = ProgressTrackerFactory.create(for: .tty)
        XCTAssertTrue(tracker is ConsoleProgressTracker)
    }

    func testProgressTrackerFactory_createsJSONTracker() {
        let tracker = ProgressTrackerFactory.create(for: .json)
        XCTAssertTrue(tracker is SilentProgressTracker)
    }

    // MARK: - Mock Tracker Tests (for protocol compliance)

    func testMockProgressTracker_recordsStartPhase() {
        let mock = MockProgressTracker()

        mock.startPhase("Git Analysis", emoji: "📊")
        mock.startPhase("Code Analysis", emoji: "📝")

        XCTAssertEqual(mock.startPhaseCalls.count, 2)
        XCTAssertEqual(mock.startPhaseCalls[0].name, "Git Analysis")
        XCTAssertEqual(mock.startPhaseCalls[0].emoji, "📊")
        XCTAssertEqual(mock.startPhaseCalls[1].name, "Code Analysis")
        XCTAssertEqual(mock.startPhaseCalls[1].emoji, "📝")
    }

    func testMockProgressTracker_recordsCompletePhase() {
        let mock = MockProgressTracker()

        let metrics = [
            Metric(id: "test", title: "Test", category: .test, value: .int(1))
        ]
        let diagnostics = [
            Diagnostic(level: .warning, message: "Warning", hint: nil)
        ]

        mock.completePhase(metrics: metrics, diagnostics: diagnostics, verbose: true)

        XCTAssertEqual(mock.completePhaseCalls.count, 1)
        XCTAssertEqual(mock.completePhaseCalls[0].metrics.count, 1)
        XCTAssertEqual(mock.completePhaseCalls[0].diagnostics.count, 1)
        XCTAssertEqual(mock.completePhaseCalls[0].verbose, true)
    }

    func testMockProgressTracker_recordsSpinnerCalls() async {
        let mock = MockProgressTracker()

        await mock.startSpinner("Loading...")
        mock.stopSpinner(success: true, message: "Done")

        XCTAssertEqual(mock.startSpinnerCalls.count, 1)
        XCTAssertEqual(mock.startSpinnerCalls[0], "Loading...")
        XCTAssertEqual(mock.stopSpinnerCalls.count, 1)
        XCTAssertEqual(mock.stopSpinnerCalls[0].success, true)
        XCTAssertEqual(mock.stopSpinnerCalls[0].message, "Done")
    }

    func testMockProgressTracker_recordsStatusCalls() {
        let mock = MockProgressTracker()

        mock.status("First status")
        mock.status("Second status")

        XCTAssertEqual(mock.statusCalls.count, 2)
        XCTAssertEqual(mock.statusCalls[0], "First status")
        XCTAssertEqual(mock.statusCalls[1], "Second status")
    }

    // MARK: - Integration Tests

    func testProgressTracker_fullWorkflow() async {
        let mock = MockProgressTracker()

        // Simulate a typical analysis workflow
        mock.startPhase("Git Analysis", emoji: "📊")
        mock.completePhase(
            metrics: [Metric(id: "git.recency", title: "Last Commit", category: .git, value: .int(1))],
            diagnostics: [],
            verbose: false
        )

        mock.startPhase("Code Analysis", emoji: "📝")
        mock.completePhase(
            metrics: [Metric(id: "code.loc", title: "Lines of Code", category: .code, value: .int(1000))],
            diagnostics: [Diagnostic(level: .info, message: "Healthy codebase", hint: nil)],
            verbose: true
        )

        await mock.startSpinner("Scanning for dead code...")
        mock.stopSpinner(success: true, message: "Complete")

        mock.status("Score: 85/100")

        // Verify workflow
        XCTAssertEqual(mock.startPhaseCalls.count, 2)
        XCTAssertEqual(mock.completePhaseCalls.count, 2)
        XCTAssertEqual(mock.startSpinnerCalls.count, 1)
        XCTAssertEqual(mock.stopSpinnerCalls.count, 1)
        XCTAssertEqual(mock.statusCalls.count, 1)
    }
}
