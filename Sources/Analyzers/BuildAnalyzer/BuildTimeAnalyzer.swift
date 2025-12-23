import Foundation
import Core

/// Analyzes Swift/Xcode build performance
public struct BuildTimeAnalyzer: Analyzer {
    public let id = "build"

    public init() {}

    public func analyze(_ context: ProjectContext, _ config: Config) async -> AnalyzerResult {
        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        // Try to find build timing data from various sources
        let timingResult = await findAndParseBuildTiming(context: context)

        if let timing = timingResult {
            metrics.append(contentsOf: timing.metrics)
            diagnostics.append(contentsOf: timing.diagnostics)
        } else {
            // Try to find DerivedData for basic build info
            let derivedDataResult = analyzeDerivedData(context: context)
            metrics.append(contentsOf: derivedDataResult.metrics)
            diagnostics.append(contentsOf: derivedDataResult.diagnostics)
        }

        if metrics.isEmpty {
            diagnostics.append(Diagnostic(
                level: .info,
                message: "No build timing data found",
                hint: "Run xcodebuild with -buildTimingSummary or provide --build-log path"
            ))
        }

        return AnalyzerResult(metrics: metrics, diagnostics: diagnostics)
    }

    // MARK: - Build Timing Parser

    private func findAndParseBuildTiming(context: ProjectContext) async -> AnalyzerResult? {
        // Look for build timing in common locations
        let possiblePaths = [
            context.artifacts.buildLogsPath,
            (context.rootPath as NSString).appendingPathComponent("build.log"),
            (context.rootPath as NSString).appendingPathComponent("xcodebuild.log")
        ].compactMap { $0 }

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                if let result = parseBuildLog(at: path) {
                    return result
                }
            }
        }

        // Try to find in DerivedData
        if let derivedData = context.artifacts.derivedDataPath ?? findDerivedData(in: context.rootPath) {
            let logsPath = (derivedData as NSString).appendingPathComponent("Logs/Build")
            if let result = await findLatestBuildLog(in: logsPath) {
                return result
            }
        }

        return nil
    }

    // FIXME: we should break this down into multiple smaller functions - its huge and hard to read
    private func parseBuildLog(at path: String) -> AnalyzerResult? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []
        var fileCompileTimes: [(file: String, time: Double)] = []
        var totalBuildTime: Double?

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            // Parse -debug-time-compilation output
            // Format: "123.45ms   /path/to/File.swift"
            if let match = parseCompileTimeLine(line) {
                fileCompileTimes.append(match)
            }

            // Parse total build time
            // Format: "Build succeeded (123.45 seconds)"
            if let time = parseTotalBuildTime(line) {
                totalBuildTime = time
            }

            // Parse -buildTimingSummary format
            // Format: "CompileSwift normal x86_64 File.swift (in target 'App') (123.45 seconds)"
            if let match = parseBuildTimingSummaryLine(line) {
                fileCompileTimes.append(match)
            }
        }

        // Calculate metrics
        if !fileCompileTimes.isEmpty {
            let sortedByTime = fileCompileTimes.sorted { $0.time > $1.time }

            // Total compile time
            let totalCompileTime = fileCompileTimes.reduce(0) { $0 + $1.time }

            metrics.append(Metric(
                id: "build.compileTime",
                title: "Total Compile Time",
                category: .build,
                value: .duration(totalCompileTime),
                unit: "s"
            ))

            // File count
            metrics.append(Metric(
                id: "build.fileCount",
                title: "Files Compiled",
                category: .build,
                value: .int(fileCompileTimes.count),
                unit: "files"
            ))

            // Average file time
            let avgTime = totalCompileTime / Double(fileCompileTimes.count)
            metrics.append(Metric(
                id: "build.avgFileTime",
                title: "Average File Compile Time",
                category: .build,
                value: .duration(avgTime),
                unit: "s"
            ))

            // Slowest file
            if let slowest = sortedByTime.first {
                let fileName = (slowest.file as NSString).lastPathComponent
                metrics.append(Metric(
                    id: "build.slowestFile",
                    title: "Slowest File",
                    category: .build,
                    value: .string(fileName),
                    details: [
                        "path": .string(slowest.file),
                        "time": .double(slowest.time)
                    ]
                ))

                if slowest.time > 2.0 {
                    diagnostics.append(Diagnostic(
                        level: .warning,
                        message: "Slow compile: \(fileName) takes \(String(format: "%.1f", slowest.time))s",
                        hint: "Consider splitting this file or optimizing complex type expressions"
                    ))
                }
            }

            // Files over 1s
            let slowFiles = sortedByTime.filter { $0.time > 1.0 }
            metrics.append(Metric(
                id: "build.filesOver1s",
                title: "Files Taking >1s",
                category: .build,
                value: .int(slowFiles.count),
                unit: "files",
                details: [
                    "files": .array(slowFiles.prefix(10).map { .string(($0.file as NSString).lastPathComponent) })
                ]
            ))

            if slowFiles.count > 5 {
                diagnostics.append(Diagnostic(
                    level: .warning,
                    message: "\(slowFiles.count) files take over 1 second to compile",
                    hint: "Run swift build with -Xswiftc -Xfrontend -Xswiftc -warn-long-function-bodies=500 to identify slow expressions"
                ))
            }
        }

        // Add total build time if found
        if let total = totalBuildTime {
            metrics.insert(Metric(
                id: "build.totalTime",
                title: "Total Build Time",
                category: .build,
                value: .duration(total),
                unit: "s"
            ), at: 0)
        }

        if metrics.isEmpty {
            return nil
        }

        return AnalyzerResult(metrics: metrics, diagnostics: diagnostics)
    }

    private func parseCompileTimeLine(_ line: String) -> (file: String, time: Double)? {
        // Match patterns like "1234.56ms  /path/to/File.swift"
        let pattern = #"^\s*(\d+\.?\d*)(ms|s)\s+(.+\.swift)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        guard let timeRange = Range(match.range(at: 1), in: line),
              let unitRange = Range(match.range(at: 2), in: line),
              let pathRange = Range(match.range(at: 3), in: line) else {
            return nil
        }

        let timeValue = Double(line[timeRange]) ?? 0
        let unit = String(line[unitRange])
        let path = String(line[pathRange]).trimmingCharacters(in: .whitespaces)

        let timeInSeconds = unit == "ms" ? timeValue / 1000.0 : timeValue
        return (file: path, time: timeInSeconds)
    }

    private func parseBuildTimingSummaryLine(_ line: String) -> (file: String, time: Double)? {
        // Match patterns like "CompileSwift normal ... File.swift ... (123.45 seconds)"
        let pattern = #"CompileSwift\s+\S+\s+\S+\s+(.+\.swift).*\((\d+\.?\d*)\s+seconds?\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        guard let pathRange = Range(match.range(at: 1), in: line),
              let timeRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let path = String(line[pathRange]).trimmingCharacters(in: .whitespaces)
        let time = Double(line[timeRange]) ?? 0

        return (file: path, time: time)
    }

    private func parseTotalBuildTime(_ line: String) -> Double? {
        // Match patterns like "Build succeeded (123.45 seconds)"
        let pattern = #"Build\s+(succeeded|completed).*\((\d+\.?\d*)\s+seconds?\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        guard let timeRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        return Double(line[timeRange])
    }

    // MARK: - DerivedData Analysis

    private func analyzeDerivedData(context: ProjectContext) -> AnalyzerResult {
        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        guard let derivedData = context.artifacts.derivedDataPath ?? findDerivedData(in: context.rootPath) else {
            return AnalyzerResult(metrics: metrics, diagnostics: diagnostics)
        }

        // Get DerivedData size
        if let size = directorySize(at: derivedData) {
            let sizeMB = Double(size) / (1024 * 1024)
            metrics.append(Metric(
                id: "build.derivedDataSize",
                title: "DerivedData Size",
                category: .build,
                value: .double(sizeMB),
                unit: "MB"
            ))

            if sizeMB > 1000 {
                diagnostics.append(Diagnostic(
                    level: .warning,
                    message: "DerivedData is \(String(format: "%.0f", sizeMB))MB",
                    hint: "Consider cleaning DerivedData periodically with 'rm -rf ~/Library/Developer/Xcode/DerivedData'"
                ))
            }
        }

        // Get last build date
        let buildPath = (derivedData as NSString).appendingPathComponent("Build")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: buildPath),
           let modDate = attrs[.modificationDate] as? Date {
            let daysSinceBuild = -modDate.timeIntervalSinceNow / 86400
            metrics.append(Metric(
                id: "build.lastBuildAge",
                title: "Last Build Age",
                category: .build,
                value: .double(daysSinceBuild),
                unit: "days"
            ))
        }

        return AnalyzerResult(metrics: metrics, diagnostics: diagnostics)
    }

    private func findDerivedData(in projectPath: String) -> String? {
        // Look for project-specific DerivedData
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let derivedDataBase = (homeDir as NSString).appendingPathComponent("Library/Developer/Xcode/DerivedData")

        guard FileManager.default.fileExists(atPath: derivedDataBase) else {
            return nil
        }

        // Get project name
        let projectName = (projectPath as NSString).lastPathComponent

        // Look for matching derived data folder
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

    private func findLatestBuildLog(in logsPath: String) async -> AnalyzerResult? {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: logsPath) else {
            return nil
        }

        // Find .xcactivitylog files
        let logs = contents.filter { $0.hasSuffix(".xcactivitylog") }
            .map { (logsPath as NSString).appendingPathComponent($0) }
            .sorted { path1, path2 in
                let date1 = (try? FileManager.default.attributesOfItem(atPath: path1)[.modificationDate] as? Date) ?? Date.distantPast
                let date2 = (try? FileManager.default.attributesOfItem(atPath: path2)[.modificationDate] as? Date) ?? Date.distantPast
                return date1 > date2
            }

        // Try to decompress and parse the most recent log
        if let latestLog = logs.first {
            return await parseXcactivityLog(at: latestLog)
        }

        return nil
    }

    private func parseXcactivityLog(at path: String) async -> AnalyzerResult? {
        // xcactivitylog files are gzip compressed
        // We can use gunzip to decompress them
        do {
            let result = try await ProcessRunner.run(
                "/usr/bin/gunzip",
                arguments: ["-c", path],
                timeout: 30
            )

            if result.succeeded {
                // Parse the decompressed content as a build log
                return parseBuildLogContent(result.standardOutput)
            }
        } catch {
            return nil
        }

        return nil
    }

    private func parseBuildLogContent(_ content: String) -> AnalyzerResult? {
        // Similar parsing to parseBuildLog but for in-memory content
        var metrics: [Metric] = []
        let diagnostics: [Diagnostic] = []
        var fileCompileTimes: [(file: String, time: Double)] = []

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            if let match = parseCompileTimeLine(line) {
                fileCompileTimes.append(match)
            }
            if let match = parseBuildTimingSummaryLine(line) {
                fileCompileTimes.append(match)
            }
        }

        if !fileCompileTimes.isEmpty {
            let totalCompileTime = fileCompileTimes.reduce(0) { $0 + $1.time }
            let avgTime = totalCompileTime / Double(fileCompileTimes.count)

            metrics.append(Metric(
                id: "build.compileTime",
                title: "Total Compile Time",
                category: .build,
                value: .duration(totalCompileTime),
                unit: "s"
            ))

            metrics.append(Metric(
                id: "build.avgFileTime",
                title: "Average File Compile Time",
                category: .build,
                value: .duration(avgTime),
                unit: "s"
            ))

            metrics.append(Metric(
                id: "build.fileCount",
                title: "Files Compiled",
                category: .build,
                value: .int(fileCompileTimes.count),
                unit: "files"
            ))
        }

        if metrics.isEmpty {
            return nil
        }

        return AnalyzerResult(metrics: metrics, diagnostics: diagnostics)
    }

    private func directorySize(at path: String) -> UInt64? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: path) else {
            return nil
        }

        var size: UInt64 = 0
        while let file = enumerator.nextObject() as? String {
            let fullPath = (path as NSString).appendingPathComponent(file)
            if let attrs = try? fm.attributesOfItem(atPath: fullPath),
               let fileSize = attrs[.size] as? UInt64 {
                size += fileSize
            }
        }

        return size
    }
}
