import Foundation
import Core

/// Analyzes Carthage dependencies
public struct CarthageAnalyzer {

    public init() {}

    /// Analyze Carthage dependencies from Cartfile.resolved
    public func analyze(at projectPath: String) -> (metrics: [Metric], diagnostics: [Diagnostic]) {
        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        let resolvedPath = (projectPath as NSString).appendingPathComponent("Cartfile.resolved")

        guard FileManager.default.fileExists(atPath: resolvedPath) else {
            diagnostics.append(Diagnostic(
                level: .info,
                message: "No Cartfile.resolved found (not using Carthage)"
            ))
            return (metrics, diagnostics)
        }

        diagnostics.append(Diagnostic(
            level: .info,
            message: "Found Cartfile.resolved"
        ))

        // Read and parse Cartfile.resolved
        guard let content = try? String(contentsOfFile: resolvedPath, encoding: .utf8) else {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "Failed to read Cartfile.resolved"
            ))
            return (metrics, diagnostics)
        }

        let dependencies = parseDependencies(from: content)
        let totalDeps = dependencies.count

        // Get file age
        let fileURL = URL(fileURLWithPath: resolvedPath)
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let modificationDate = attributes?[.modificationDate] as? Date
        let daysOld = modificationDate.map { -$0.timeIntervalSinceNow / 86400 } ?? 0

        // Count potentially outdated (lockfile older than 30 days)
        let outdatedCount = daysOld > 30 ? totalDeps : 0
        let outdatedPercent = totalDeps > 0 ? Double(outdatedCount) / Double(totalDeps) : 0.0

        metrics.append(Metric(
            id: "deps.carthage.total",
            title: "Carthage Dependencies",
            category: .dependencies,
            value: .int(totalDeps),
            unit: "count",
            details: [
                "frameworks": .array(dependencies.prefix(10).map { .string("\($0.name) (\($0.version))") })
            ]
        ))

        metrics.append(Metric(
            id: "deps.carthage.lockfileAge",
            title: "Cartfile.resolved Age",
            category: .dependencies,
            value: .double(daysOld),
            unit: "days"
        ))

        // Contribute to overall outdated metric
        metrics.append(Metric(
            id: "deps.outdated",
            title: "Potentially Outdated Dependencies",
            category: .dependencies,
            value: .int(outdatedCount),
            unit: "count",
            details: [
                "total": .int(totalDeps),
                "percent": .double(outdatedPercent),
                "type": .string("carthage")
            ]
        ))

        if daysOld > 90 {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "Cartfile.resolved is \(Int(daysOld)) days old - dependencies may be outdated",
                hint: "Run 'carthage update' to update dependencies"
            ))
        }

        return (metrics, diagnostics)
    }

    /// Parse Cartfile.resolved format
    /// Example lines:
    /// github "Alamofire/Alamofire" "5.4.3"
    /// git "https://example.com/repo.git" "v1.2.3"
    /// binary "https://example.com/framework.json" "2.0.0"
    private func parseDependencies(from content: String) -> [Dependency] {
        var dependencies: [Dependency] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Parse format: [type] "[source]" "[version]"
            let components = parseCartfileLine(trimmed)
            if let type = components.type, let source = components.source, let version = components.version {
                let name = extractName(from: source, type: type)
                dependencies.append(Dependency(name: name, version: version, type: type))
            }
        }

        return dependencies
    }

    /// Parse a Cartfile.resolved line
    private func parseCartfileLine(_ line: String) -> (type: String?, source: String?, version: String?) {
        // Split by quotes
        let parts = line.split(separator: "\"").map { String($0).trimmingCharacters(in: .whitespaces) }

        guard parts.count >= 5 else { return (nil, nil, nil) }

        let type = parts[0]  // github, git, binary
        let source = parts[1]  // repo path or URL
        let version = parts[3]  // version string

        return (type, source, version)
    }

    /// Extract dependency name from source
    private func extractName(from source: String, type: String) -> String {
        if type == "github" {
            // Extract "Alamofire" from "Alamofire/Alamofire"
            if let lastComponent = source.components(separatedBy: "/").last {
                return lastComponent
            }
        } else if type == "git" {
            // Extract repo name from URL
            if let lastComponent = source.components(separatedBy: "/").last {
                return lastComponent.replacingOccurrences(of: ".git", with: "")
            }
        }

        return source
    }

    struct Dependency {
        let name: String
        let version: String
        let type: String
    }
}
