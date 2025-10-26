import Foundation
import Core

/// Analyzes Swift Package Manager dependencies
public struct SPMAnalyzer {

    public init() {}

    /// Analyze SPM dependencies from Package.resolved
    public func analyze(at projectPath: String) -> (metrics: [Metric], diagnostics: [Diagnostic]) {
        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        // Look for Package.resolved in common locations
        let possiblePaths = [
            (projectPath as NSString).appendingPathComponent("Package.resolved"),
            (projectPath as NSString).appendingPathComponent(".build/workspace-state.json"),
            (projectPath as NSString).appendingPathComponent("*.xcworkspace/xcshareddata/swiftpm/Package.resolved")
        ]

        var resolvedPath: String?
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                resolvedPath = path
                break
            }
        }

        // Check workspace directory manually
        if resolvedPath == nil {
            if let workspaceDir = findWorkspaceDirectory(in: projectPath) {
                let workspacePath = (workspaceDir as NSString).appendingPathComponent("xcshareddata/swiftpm/Package.resolved")
                if FileManager.default.fileExists(atPath: workspacePath) {
                    resolvedPath = workspacePath
                }
            }
        }

        guard let path = resolvedPath else {
            diagnostics.append(Diagnostic(
                level: .info,
                message: "No Package.resolved found (not using SPM)"
            ))
            return (metrics, diagnostics)
        }

        diagnostics.append(Diagnostic(
            level: .info,
            message: "Found Package.resolved at \(path)"
        ))

        // Parse Package.resolved
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let resolved = try? JSONDecoder().decode(PackageResolved.self, from: data) else {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "Failed to parse Package.resolved"
            ))
            return (metrics, diagnostics)
        }

        let totalDeps = resolved.pins.count

        // Get file age
        let fileURL = URL(fileURLWithPath: path)
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let modificationDate = attributes?[.modificationDate] as? Date
        let daysOld = modificationDate.map { -$0.timeIntervalSinceNow / 86400 } ?? 0

        // Count potentially outdated (lockfile older than 30 days)
        let outdatedCount = daysOld > 30 ? totalDeps : 0
        let outdatedPercent = totalDeps > 0 ? Double(outdatedCount) / Double(totalDeps) : 0.0

        metrics.append(Metric(
            id: "deps.spm.total",
            title: "SPM Dependencies",
            category: .dependencies,
            value: .int(totalDeps),
            unit: "count",
            details: [
                "packages": .array(resolved.pins.prefix(10).map { .string("\($0.identity)") })
            ]
        ))

        metrics.append(Metric(
            id: "deps.spm.lockfileAge",
            title: "SPM Lockfile Age",
            category: .dependencies,
            value: .double(daysOld),
            unit: "days"
        ))

        metrics.append(Metric(
            id: "deps.outdated",
            title: "Potentially Outdated Dependencies",
            category: .dependencies,
            value: .int(outdatedCount),
            unit: "count",
            details: [
                "total": .int(totalDeps),
                "percent": .double(outdatedPercent)
            ]
        ))

        if daysOld > 90 {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "Package.resolved is \(Int(daysOld)) days old - dependencies may be outdated",
                hint: "Run 'swift package update' to update dependencies"
            ))
        }

        return (metrics, diagnostics)
    }

    /// Find .xcworkspace directory
    private func findWorkspaceDirectory(in path: String) -> String? {
        guard let enumerator = FileManager.default.enumerator(atPath: path) else {
            return nil
        }

        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".xcworkspace") {
                return (path as NSString).appendingPathComponent(file)
            }
        }

        return nil
    }
}

// MARK: - Package.resolved Models

/// Package.resolved file structure (SPM format)
private struct PackageResolved: Codable {
    let version: Int?
    let object: ObjectContainer?
    let pins: [Pin]

    enum CodingKeys: String, CodingKey {
        case version
        case object
        case pins
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try? container.decode(Int.self, forKey: .version)
        object = try? container.decode(ObjectContainer.self, forKey: .object)

        // Try to decode pins directly or from object.pins
        if let directPins = try? container.decode([Pin].self, forKey: .pins) {
            pins = directPins
        } else if let objectPins = object?.pins {
            pins = objectPins
        } else {
            pins = []
        }
    }

    struct ObjectContainer: Codable {
        let pins: [Pin]
    }
}

private struct Pin: Codable {
    let identity: String
    let location: String?
    let state: PinState?
    let package: String?  // v1 format
    let repositoryURL: String?  // v1 format

    enum CodingKeys: String, CodingKey {
        case identity
        case location
        case state
        case package
        case repositoryURL
    }
}

private struct PinState: Codable {
    let version: String?
    let revision: String?
    let branch: String?
}
