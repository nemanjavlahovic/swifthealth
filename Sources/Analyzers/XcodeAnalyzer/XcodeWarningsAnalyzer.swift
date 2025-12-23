import Foundation
import Core

/// Analyzes Xcode compiler warnings from build logs and xcresult bundles
public struct XcodeWarningsAnalyzer: Analyzer {
    public let id = "xcode"

    public init() {}

    public func analyze(_ context: ProjectContext, _ config: Config) async -> AnalyzerResult {
        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        // Try multiple sources for warnings
        var warnings: [CompilerWarning] = []

        // 1. Try xcresult bundle if provided
        if let xcresultPath = context.artifacts.xcresultPath {
            let xcresultWarnings = await parseXcresult(at: xcresultPath)
            warnings.append(contentsOf: xcresultWarnings)
        }

        // 2. Try to find xcresult in DerivedData
        if warnings.isEmpty {
            if let derivedData = context.artifacts.derivedDataPath ?? findDerivedData(in: context.rootPath) {
                let logsPath = (derivedData as NSString).appendingPathComponent("Logs/Test")
                if let xcresultPath = findLatestXcresult(in: logsPath) {
                    let xcresultWarnings = await parseXcresult(at: xcresultPath)
                    warnings.append(contentsOf: xcresultWarnings)
                }
            }
        }

        // 3. Try build log if provided
        if warnings.isEmpty, let buildLogsPath = context.artifacts.buildLogsPath {
            let logWarnings = parseBuildLog(at: buildLogsPath)
            warnings.append(contentsOf: logWarnings)
        }

        // Generate metrics if we found warnings
        if !warnings.isEmpty {
            metrics.append(contentsOf: generateMetrics(from: warnings))
            diagnostics.append(contentsOf: generateDiagnostics(from: warnings))
        } else {
            diagnostics.append(Diagnostic(
                level: .info,
                message: "No Xcode warnings data found",
                hint: "Provide --xcresult or --build-log path for Xcode warning analysis"
            ))
        }

        return AnalyzerResult(metrics: metrics, diagnostics: diagnostics)
    }

    // MARK: - Xcresult Parsing

    private func parseXcresult(at path: String) async -> [CompilerWarning] {
        var warnings: [CompilerWarning] = []

        // Use xcrun xcresulttool to extract warnings
        do {
            // Get the results as JSON
            let result = try await ProcessRunner.run(
                "/usr/bin/xcrun",
                arguments: ["xcresulttool", "get", "--path", path, "--format", "json"],
                timeout: 60
            )

            if result.succeeded {
                warnings = parseXcresultJSON(result.standardOutput)
            }
        } catch {
            // xcresulttool not available or failed
        }

        return warnings
    }

    private func parseXcresultJSON(_ json: String) -> [CompilerWarning] {
        var warnings: [CompilerWarning] = []

        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return warnings
        }

        // Navigate xcresult JSON structure to find warnings
        // The structure varies by Xcode version, so we search recursively
        findWarningsInJSON(root, warnings: &warnings)

        return warnings
    }

    private func findWarningsInJSON(_ object: Any, warnings: inout [CompilerWarning]) {
        if let dict = object as? [String: Any] {
            // Check if this is a warning node
            if let type = dict["_type"] as? [String: String],
               type["_name"] == "IssueSummary" || type["_name"] == "IssueMessage" {
                if let message = extractString(from: dict["message"]),
                   message.lowercased().contains("warning") || dict["issueType"] as? String == "Warning" {
                    let warning = CompilerWarning(
                        message: message,
                        file: extractString(from: dict["documentLocationInCreatingWorkspace"]),
                        line: nil,
                        category: categorizeWarning(message)
                    )
                    warnings.append(warning)
                }
            }

            // Recurse into nested objects
            for (_, value) in dict {
                findWarningsInJSON(value, warnings: &warnings)
            }
        } else if let array = object as? [Any] {
            for item in array {
                findWarningsInJSON(item, warnings: &warnings)
            }
        }
    }

    private func extractString(from value: Any?) -> String? {
        if let str = value as? String {
            return str
        }
        if let dict = value as? [String: Any], let val = dict["_value"] as? String {
            return val
        }
        return nil
    }

    // MARK: - Build Log Parsing

    private func parseBuildLog(at path: String) -> [CompilerWarning] {
        var warnings: [CompilerWarning] = []

        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return warnings
        }

        let lines = content.components(separatedBy: .newlines)

        // Pattern for compiler warnings
        // Format: /path/to/File.swift:123:45: warning: Some warning message
        let warningPattern = #"^(.+\.swift):(\d+):(\d+):\s*warning:\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: warningPattern, options: []) else {
            return warnings
        }

        for line in lines {
            if let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) {
                guard let fileRange = Range(match.range(at: 1), in: line),
                      let lineRange = Range(match.range(at: 2), in: line),
                      let messageRange = Range(match.range(at: 4), in: line) else {
                    continue
                }

                let file = String(line[fileRange])
                let lineNum = Int(line[lineRange])
                let message = String(line[messageRange])

                let warning = CompilerWarning(
                    message: message,
                    file: file,
                    line: lineNum,
                    category: categorizeWarning(message)
                )
                warnings.append(warning)
            }
        }

        return warnings
    }

    // MARK: - Warning Categorization

    private func categorizeWarning(_ message: String) -> WarningCategory {
        let lowercased = message.lowercased()

        if lowercased.contains("deprecated") {
            return .deprecation
        }
        if lowercased.contains("unused") || lowercased.contains("never used") || lowercased.contains("never read") {
            return .unused
        }
        if lowercased.contains("implicit") || lowercased.contains("conversion") {
            return .implicitConversion
        }
        if lowercased.contains("type") && (lowercased.contains("mismatch") || lowercased.contains("inference")) {
            return .typeMismatch
        }
        if lowercased.contains("init") || lowercased.contains("property") {
            return .initialization
        }

        return .other
    }

    // MARK: - Metrics Generation

    private func generateMetrics(from warnings: [CompilerWarning]) -> [Metric] {
        var metrics: [Metric] = []

        // Total warnings
        metrics.append(Metric(
            id: "xcode.warnings.total",
            title: "Xcode Warnings",
            category: .build,
            value: .int(warnings.count),
            unit: "count"
        ))

        // Group by category
        var categoryCounts: [WarningCategory: Int] = [:]
        for warning in warnings {
            categoryCounts[warning.category, default: 0] += 1
        }

        // Category-specific metrics
        if let deprecation = categoryCounts[.deprecation], deprecation > 0 {
            metrics.append(Metric(
                id: "xcode.warnings.deprecation",
                title: "Deprecation Warnings",
                category: .build,
                value: .int(deprecation),
                unit: "count"
            ))
        }

        if let unused = categoryCounts[.unused], unused > 0 {
            metrics.append(Metric(
                id: "xcode.warnings.unused",
                title: "Unused Code Warnings",
                category: .build,
                value: .int(unused),
                unit: "count"
            ))
        }

        // Group by file
        var fileCounts: [String: Int] = [:]
        for warning in warnings {
            if let file = warning.file {
                let fileName = (file as NSString).lastPathComponent
                fileCounts[fileName, default: 0] += 1
            }
        }

        // Find worst offenders
        let sortedFiles = fileCounts.sorted { $0.value > $1.value }
        if !sortedFiles.isEmpty {
            let topOffenders = Array(sortedFiles.prefix(5))
            metrics.append(Metric(
                id: "xcode.warnings.topFiles",
                title: "Most Warnings Per File",
                category: .build,
                value: .int(topOffenders.first?.value ?? 0),
                details: [
                    "files": .array(topOffenders.map { .dictionary(["name": .string($0.key), "count": .int($0.value)]) })
                ]
            ))
        }

        return metrics
    }

    private func generateDiagnostics(from warnings: [CompilerWarning]) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []

        // Summarize warning counts
        if warnings.count > 50 {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "\(warnings.count) compiler warnings detected",
                hint: "Consider addressing warnings to improve code quality"
            ))
        } else if warnings.count > 10 {
            diagnostics.append(Diagnostic(
                level: .info,
                message: "\(warnings.count) compiler warnings detected"
            ))
        }

        // Highlight deprecation warnings
        let deprecationCount = warnings.filter { $0.category == .deprecation }.count
        if deprecationCount > 0 {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "\(deprecationCount) deprecation warnings - APIs may be removed in future OS versions",
                hint: "Update to non-deprecated APIs before the next major OS release"
            ))
        }

        return diagnostics
    }

    // MARK: - Helpers

    private func findDerivedData(in projectPath: String) -> String? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let derivedDataBase = (homeDir as NSString).appendingPathComponent("Library/Developer/Xcode/DerivedData")

        guard FileManager.default.fileExists(atPath: derivedDataBase) else {
            return nil
        }

        let projectName = (projectPath as NSString).lastPathComponent

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: derivedDataBase) else {
            return nil
        }

        for folder in contents {
            if folder.hasPrefix(projectName) {
                return (derivedDataBase as NSString).appendingPathComponent(folder)
            }
        }

        return nil
    }

    private func findLatestXcresult(in logsPath: String) -> String? {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: logsPath) else {
            return nil
        }

        let xcresults = contents.filter { $0.hasSuffix(".xcresult") }
            .map { (logsPath as NSString).appendingPathComponent($0) }
            .sorted { path1, path2 in
                let date1 = (try? FileManager.default.attributesOfItem(atPath: path1)[.modificationDate] as? Date) ?? Date.distantPast
                let date2 = (try? FileManager.default.attributesOfItem(atPath: path2)[.modificationDate] as? Date) ?? Date.distantPast
                return date1 > date2
            }

        return xcresults.first
    }
}

// MARK: - Supporting Types

private struct CompilerWarning {
    let message: String
    let file: String?
    let line: Int?
    let category: WarningCategory
}

private enum WarningCategory {
    case deprecation
    case unused
    case implicitConversion
    case typeMismatch
    case initialization
    case other
}
