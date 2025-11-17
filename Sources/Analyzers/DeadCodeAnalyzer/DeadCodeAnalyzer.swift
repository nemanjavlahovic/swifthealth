import Foundation
import Core

/// Analyzes dead code using Periphery
public struct DeadCodeAnalyzer: Analyzer {
    public let id = "deadcode"

    public init() {}

    public func analyze(_ context: ProjectContext, _ config: Config) async -> AnalyzerResult {
        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        // 1. Check if periphery binary is available
        guard let peripheryPath = await findPeriphery() else {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "periphery not found in PATH",
                hint: "Install with: brew install periphery"
            ))
            return AnalyzerResult(metrics: [], diagnostics: diagnostics)
        }

        diagnostics.append(Diagnostic(
            level: .info,
            message: "Found periphery at \(peripheryPath)"
        ))

        // 2. Run periphery scan
        let scanResult = await runPeriphery(in: context.rootPath, peripheryPath: peripheryPath)

        guard let results = scanResult.results else {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "Failed to run periphery scan",
                hint: scanResult.error ?? "Try running 'periphery scan' manually to debug"
            ))
            return AnalyzerResult(metrics: [], diagnostics: diagnostics)
        }

        // 3. Filter for actual unused code (not just redundant public accessibility)
        let unusedResults = results.filter { $0.isUnused }

        // 4. Group by kind to get breakdown
        let kindGroups = Dictionary(grouping: unusedResults, by: { $0.kind })

        // 5. Create metrics
        metrics.append(Metric(
            id: "deadcode.unused_count",
            title: "Unused Declarations",
            category: .code,
            value: .int(unusedResults.count),
            unit: "count",
            details: [
                "total": .int(results.count),
                "kinds": .array(kindGroups.map { .string("\($0.key): \($0.value.count)") })
            ]
        ))

        // 6. Add diagnostics based on findings
        if unusedResults.count > 0 {
            let topKinds = kindGroups
                .map { (kind: $0.key, count: $0.value.count) }
                .sorted { $0.count > $1.count }
                .prefix(3)

            diagnostics.append(Diagnostic(
                level: .warning,
                message: "\(unusedResults.count) unused declarations found",
                hint: "Top kinds: \(topKinds.map { "\($0.kind): \($0.count)" }.joined(separator: ", "))"
            ))
        } else {
            diagnostics.append(Diagnostic(
                level: .info,
                message: "No unused code detected - excellent!"
            ))
        }

        return AnalyzerResult(metrics: metrics, diagnostics: diagnostics)
    }

    // MARK: - Helper Methods

    /// Find periphery binary in PATH
    private func findPeriphery() async -> String? {
        // Common installation paths for periphery
        let commonPaths = [
            "/opt/homebrew/bin/periphery",  // Homebrew on Apple Silicon
            "/usr/local/bin/periphery",      // Homebrew on Intel
            "/usr/bin/periphery"             // System path
        ]

        // Check common paths first
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Fall back to using 'which' command
        do {
            let result = try await ProcessRunner.run("/usr/bin/which", arguments: ["periphery"])
            guard result.succeeded else { return nil }
            return result.standardOutput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// Run periphery scan and parse results
    private func runPeriphery(in path: String, peripheryPath: String) async -> (results: [PeripheryResult]?, error: String?) {
        do {
            let result = try await ProcessRunner.run(
                peripheryPath,
                arguments: ["scan", "--format", "json"],
                workingDirectory: path,
                timeout: 120  // Periphery can take a while on large projects
            )

            // Periphery writes progress to stderr and results to stdout
            // Empty stdout means no results (not necessarily an error)
            guard !result.standardOutput.isEmpty else {
                // No results is actually success (no dead code found!)
                return ([], nil)
            }

            // Parse JSON output
            guard let data = result.standardOutput.data(using: String.Encoding.utf8) else {
                return (nil, "Failed to parse periphery output as UTF-8")
            }

            do {
                let results = try JSONDecoder().decode([PeripheryResult].self, from: data)
                return (results, nil)
            } catch {
                // Include first 200 chars of stdout for debugging
                let preview = String(result.standardOutput.prefix(200))
                return (nil, "JSON decode error: \(error.localizedDescription). Output preview: \(preview)")
            }

        } catch let error {
            return (nil, error.localizedDescription)
        }
    }
}
