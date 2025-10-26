import Foundation
import Core

/// Analyzes CocoaPods dependencies
public struct CocoaPodsAnalyzer {

    public init() {}

    /// Analyze CocoaPods dependencies from Podfile.lock
    public func analyze(at projectPath: String) -> (metrics: [Metric], diagnostics: [Diagnostic]) {
        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        let lockfilePath = (projectPath as NSString).appendingPathComponent("Podfile.lock")

        guard FileManager.default.fileExists(atPath: lockfilePath) else {
            diagnostics.append(Diagnostic(
                level: .info,
                message: "No Podfile.lock found (not using CocoaPods)"
            ))
            return (metrics, diagnostics)
        }

        diagnostics.append(Diagnostic(
            level: .info,
            message: "Found Podfile.lock"
        ))

        // Read and parse Podfile.lock
        guard let content = try? String(contentsOfFile: lockfilePath, encoding: .utf8) else {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "Failed to read Podfile.lock"
            ))
            return (metrics, diagnostics)
        }

        let pods = parsePods(from: content)
        let totalPods = pods.count

        // Get file age
        let fileURL = URL(fileURLWithPath: lockfilePath)
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let modificationDate = attributes?[.modificationDate] as? Date
        let daysOld = modificationDate.map { -$0.timeIntervalSinceNow / 86400 } ?? 0

        // Count potentially outdated (lockfile older than 30 days)
        let outdatedCount = daysOld > 30 ? totalPods : 0
        let outdatedPercent = totalPods > 0 ? Double(outdatedCount) / Double(totalPods) : 0.0

        metrics.append(Metric(
            id: "deps.pods.total",
            title: "CocoaPods Dependencies",
            category: .dependencies,
            value: .int(totalPods),
            unit: "count",
            details: [
                "pods": .array(pods.prefix(10).map { .string("\($0.name) (\($0.version))") })
            ]
        ))

        metrics.append(Metric(
            id: "deps.pods.lockfileAge",
            title: "Podfile.lock Age",
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
                "total": .int(totalPods),
                "percent": .double(outdatedPercent),
                "type": .string("cocoapods")
            ]
        ))

        if daysOld > 90 {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "Podfile.lock is \(Int(daysOld)) days old - dependencies may be outdated",
                hint: "Run 'pod update' to update dependencies"
            ))
        }

        return (metrics, diagnostics)
    }

    /// Parse PODS section from Podfile.lock
    private func parsePods(from content: String) -> [Pod] {
        var pods: [Pod] = []
        let lines = content.components(separatedBy: .newlines)

        var inPodsSection = false
        for line in lines {
            // Detect PODS section
            if line.starts(with: "PODS:") {
                inPodsSection = true
                continue
            }

            // End of PODS section
            if inPodsSection && !line.starts(with: "  ") && !line.isEmpty {
                break
            }

            if inPodsSection {
                // Parse pod entries like "  - Alamofire (5.4.3)"
                if let pod = parsePodLine(line) {
                    pods.append(pod)
                }
            }
        }

        return pods
    }

    /// Parse a single pod line
    private func parsePodLine(_ line: String) -> Pod? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Main pods start with "- "
        guard trimmed.hasPrefix("- ") else { return nil }

        let content = String(trimmed.dropFirst(2))  // Remove "- "

        // Pattern: "PodName (version)" or "PodName/Subspec (version)"
        if let range = content.range(of: #"\(([^)]+)\)"#, options: .regularExpression) {
            let nameEndIndex = content.index(before: range.lowerBound)
            let name = String(content[..<nameEndIndex]).trimmingCharacters(in: .whitespaces)
            let version = String(content[range]).replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            return Pod(name: name, version: version)
        }

        return nil
    }

    struct Pod {
        let name: String
        let version: String
    }
}
