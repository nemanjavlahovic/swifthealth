import Foundation
import Core

/// Analyzes SwiftLint violations (warnings and errors)
public struct SwiftLintAnalyzer: Analyzer {
    public let id = "lint"

    public init() {}

    public func analyze(_ context: ProjectContext, _ config: Config) async -> AnalyzerResult {
        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        // 1. Check if .swiftlint.yml exists
        let configPath = (context.rootPath as NSString).appendingPathComponent(".swiftlint.yml")
        let configExists = FileManager.default.fileExists(atPath: configPath)

        if !configExists {
            diagnostics.append(Diagnostic(
                level: .info,
                message: "No .swiftlint.yml config found",
                hint: "Run 'swiftlint init' to create a default configuration"
            ))
            return AnalyzerResult(metrics: [], diagnostics: diagnostics)
        }

        // 2. Check if swiftlint binary is available
        guard let swiftlintPath = await findSwiftLint() else {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "swiftlint not found in PATH",
                hint: "Install with: brew install swiftlint"
            ))
            return AnalyzerResult(metrics: [], diagnostics: diagnostics)
        }

        diagnostics.append(Diagnostic(
            level: .info,
            message: "Found swiftlint at \(swiftlintPath)"
        ))

        // 3. Run swiftlint lint --reporter json
        guard let violations = await runSwiftLint(in: context.rootPath) else {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "Failed to run swiftlint",
                hint: "Try running 'swiftlint lint' manually to debug"
            ))
            return AnalyzerResult(metrics: [], diagnostics: diagnostics)
        }

        // 4. Count violations by severity
        let warnings = violations.filter { $0.severity == "warning" }
        let errors = violations.filter { $0.severity == "error" }

        // 5. Group by rule to find top offenders
        let ruleGroups = Dictionary(grouping: violations, by: { $0.rule })
        let topRules = ruleGroups
            .map { (rule: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)

        // 6. Create metrics
        metrics.append(Metric(
            id: "lint.warnings",
            title: "SwiftLint Warnings",
            category: .lint,
            value: .int(warnings.count),
            unit: "count",
            details: [
                "total": .int(violations.count),
                "topRules": .array(topRules.map { .string("\($0.rule): \($0.count)") })
            ]
        ))

        metrics.append(Metric(
            id: "lint.errors",
            title: "SwiftLint Errors",
            category: .lint,
            value: .int(errors.count),
            unit: "count"
        ))

        // 7. Add diagnostics for high violation counts
        if errors.count > 0 {
            diagnostics.append(Diagnostic(
                level: .error,
                message: "\(errors.count) SwiftLint errors found",
                hint: "Fix errors before warnings for maximum impact"
            ))
        }

        if warnings.count > 50 {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "\(warnings.count) SwiftLint warnings found",
                hint: "Top rules: \(topRules.prefix(3).map { $0.rule }.joined(separator: ", "))"
            ))
        }

        return AnalyzerResult(metrics: metrics, diagnostics: diagnostics)
    }

    // MARK: - Helper Methods

    /// Find swiftlint binary in PATH
    private func findSwiftLint() async -> String? {
        do {
            let result = try await ProcessRunner.run("which", arguments: ["swiftlint"])
            guard result.succeeded else { return nil }
            return result.standardOutput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// Run swiftlint and parse violations
    private func runSwiftLint(in path: String) async -> [SwiftLintViolation]? {
        do {
            let result = try await ProcessRunner.run(
                "swiftlint",
                arguments: ["lint", "--reporter", "json", "--quiet"],
                workingDirectory: path
            )

            // SwiftLint exits with non-zero if violations found, but that's expected
            // We only care if the command itself failed (crash, not found, etc.)
            guard !result.standardOutput.isEmpty else {
                return nil
            }

            // Parse JSON output
            let data = result.standardOutput.data(using: String.Encoding.utf8) ?? Data()
            let violations = try JSONDecoder().decode([SwiftLintViolation].self, from: data)
            return violations

        } catch {
            return nil
        }
    }
}

// MARK: - SwiftLint JSON Models

/// Represents a single SwiftLint violation
private struct SwiftLintViolation: Codable {
    let rule: String           // e.g., "force_cast", "line_length"
    let severity: String       // "warning" or "error"
    let file: String           // File path
    let line: Int?             // Line number
    let character: Int?        // Character position
    let reason: String         // Human-readable explanation

    enum CodingKeys: String, CodingKey {
        case rule = "rule_id"
        case severity
        case file
        case line
        case character
        case reason
    }
}
