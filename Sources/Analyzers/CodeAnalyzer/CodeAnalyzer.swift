import Foundation
import Core

/// Analyzes code metrics (LOC, files, structure)
public struct CodeAnalyzer: Analyzer {
    public let id = "code"

    public init() {}

    public func analyze(_ context: ProjectContext, _ config: Config) async -> AnalyzerResult {
        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        // Scan directory for code files
        let codeStats = scanDirectory(context.rootPath)

        // Total files
        metrics.append(Metric(
            id: "code.files.total",
            title: "Total Code Files",
            category: .code,
            value: .int(codeStats.totalFiles),
            unit: "files",
            details: [
                "swift": .int(codeStats.swiftFiles),
                "objc": .int(codeStats.objcFiles),
                "headers": .int(codeStats.headerFiles)
            ]
        ))

        // Total LOC
        metrics.append(Metric(
            id: "code.loc.total",
            title: "Total Lines of Code",
            category: .code,
            value: .int(codeStats.totalLOC),
            unit: "lines",
            details: [
                "swift": .int(codeStats.swiftLOC),
                "objc": .int(codeStats.objcLOC),
                "comments": .int(codeStats.commentLines)
            ]
        ))

        // Comment density
        if codeStats.totalLOC > 0 {
            let commentDensity = Double(codeStats.commentLines) / Double(codeStats.totalLOC)
            metrics.append(Metric(
                id: "code.comments.density",
                title: "Comment Density",
                category: .code,
                value: .percent(commentDensity),
                details: [
                    "commentLines": .int(codeStats.commentLines),
                    "totalLines": .int(codeStats.totalLOC)
                ]
            ))

            // Diagnostic for low comment density
            if commentDensity < 0.05 {
                diagnostics.append(Diagnostic(
                    level: .info,
                    message: "Low comment density (\(Int(commentDensity * 100))%)",
                    hint: "Consider adding more documentation comments"
                ))
            }
        }

        // Average file size
        if codeStats.totalFiles > 0 {
            let avgFileSize = codeStats.totalLOC / codeStats.totalFiles
            metrics.append(Metric(
                id: "code.files.avgSize",
                title: "Average File Size",
                category: .code,
                value: .int(avgFileSize),
                unit: "lines/file"
            ))

            // Diagnostic for large files
            if avgFileSize > 500 {
                diagnostics.append(Diagnostic(
                    level: .warning,
                    message: "Large average file size (\(avgFileSize) lines)",
                    hint: "Consider breaking down large files into smaller modules"
                ))
            }
        }

        // Swift vs Objective-C ratio
        let totalSourceLOC = codeStats.swiftLOC + codeStats.objcLOC
        if totalSourceLOC > 0 {
            let swiftPercent = Double(codeStats.swiftLOC) / Double(totalSourceLOC)
            metrics.append(Metric(
                id: "code.language.swift",
                title: "Swift Percentage",
                category: .code,
                value: .percent(swiftPercent),
                details: [
                    "swiftLOC": .int(codeStats.swiftLOC),
                    "objcLOC": .int(codeStats.objcLOC)
                ]
            ))
        }

        return AnalyzerResult(metrics: metrics, diagnostics: diagnostics)
    }

    // MARK: - Directory Scanning

    private func scanDirectory(_ path: String) -> CodeStats {
        var stats = CodeStats()

        guard let enumerator = FileManager.default.enumerator(atPath: path) else {
            return stats
        }

        // Directories to skip
        let skipDirs = [
            ".build", ".git", "Pods", "Carthage", "DerivedData",
            ".swiftpm", "xcuserdata", "build", "node_modules"
        ]

        while let file = enumerator.nextObject() as? String {
            // Skip hidden files and common build directories
            if file.hasPrefix(".") || skipDirs.contains(where: { file.hasPrefix($0) }) {
                continue
            }

            let fullPath = (path as NSString).appendingPathComponent(file)

            // Check file extension
            if file.hasSuffix(".swift") {
                stats.swiftFiles += 1
                let loc = countLines(at: fullPath)
                stats.swiftLOC += loc.code
                stats.commentLines += loc.comments
            } else if file.hasSuffix(".m") || file.hasSuffix(".mm") {
                stats.objcFiles += 1
                let loc = countLines(at: fullPath)
                stats.objcLOC += loc.code
                stats.commentLines += loc.comments
            } else if file.hasSuffix(".h") {
                stats.headerFiles += 1
                let loc = countLines(at: fullPath)
                stats.objcLOC += loc.code
                stats.commentLines += loc.comments
            }
        }

        return stats
    }

    // MARK: - Line Counting

    private func countLines(at path: String) -> (code: Int, comments: Int) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return (0, 0)
        }

        let lines = content.components(separatedBy: .newlines)
        var codeLines = 0
        var commentLines = 0
        var inMultiLineComment = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            if trimmed.isEmpty {
                continue
            }

            // Check for multi-line comments
            if trimmed.hasPrefix("/*") {
                inMultiLineComment = true
                commentLines += 1
                if trimmed.contains("*/") {
                    inMultiLineComment = false
                }
                continue
            }

            if inMultiLineComment {
                commentLines += 1
                if trimmed.contains("*/") {
                    inMultiLineComment = false
                }
                continue
            }

            // Single-line comment
            if trimmed.hasPrefix("//") {
                commentLines += 1
                continue
            }

            // Code line
            codeLines += 1
        }

        return (codeLines, commentLines)
    }
}

// MARK: - Supporting Types

private struct CodeStats {
    var swiftFiles = 0
    var objcFiles = 0
    var headerFiles = 0

    var swiftLOC = 0
    var objcLOC = 0
    var commentLines = 0

    var totalFiles: Int {
        swiftFiles + objcFiles + headerFiles
    }

    var totalLOC: Int {
        swiftLOC + objcLOC
    }
}
