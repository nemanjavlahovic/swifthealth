import Foundation
import Core

/// Detects project types and locates relevant files/artifacts
public struct ProjectDetector {
    private let fileManager = FileManager.default

    public init() {}

    /// Discover project information at the given path
    /// - Parameter rootPath: Absolute path to the project root
    /// - Returns: ProjectContext with detected types and artifact paths
    public func discover(at rootPath: String) -> ProjectContext {
        var detectedTypes: [ProjectType] = []
        var artifacts = Artifacts()

        // Check for Git repository
        if fileExists(at: rootPath, path: ".git") {
            detectedTypes.append(.git)
        }

        // Check for SPM (Swift Package Manager)
        if fileExists(at: rootPath, path: "Package.swift") {
            detectedTypes.append(.spm)
        }

        // Check for Xcode project
        if !findFiles(at: rootPath, withExtension: "xcodeproj").isEmpty {
            detectedTypes.append(.xcodeproj)
        }

        // Check for Xcode workspace
        if !findFiles(at: rootPath, withExtension: "xcworkspace").isEmpty {
            detectedTypes.append(.xcworkspace)
        }

        // Check for CocoaPods
        if fileExists(at: rootPath, path: "Podfile.lock") {
            detectedTypes.append(.cocoapods)
        }

        // Check for Carthage
        if fileExists(at: rootPath, path: "Cartfile.resolved") {
            detectedTypes.append(.carthage)
        }

        // Locate DerivedData (best-effort)
        artifacts = Artifacts(
            derivedDataPath: findDerivedData(for: rootPath),
            xcresultPath: findXCResult(at: rootPath),
            buildLogsPath: nil  // TODO: implement if needed
        )

        return ProjectContext(
            rootPath: rootPath,
            projectTypes: detectedTypes,
            offline: false,  // Will be overridden by CLI flag
            artifacts: artifacts
        )
    }

    // MARK: - Helper Methods

    /// Check if a file or directory exists at the given path
    private func fileExists(at root: String, path: String) -> Bool {
        let fullPath = URL(fileURLWithPath: root).appendingPathComponent(path).path
        return fileManager.fileExists(atPath: fullPath)
    }

    /// Find all files with a specific extension in the root directory
    private func findFiles(at root: String, withExtension ext: String) -> [String] {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: root) else {
            return []
        }

        return contents.filter { $0.hasSuffix(".\(ext)") }
    }

    /// Try to find DerivedData directory
    /// First checks for project-specific DerivedData, then falls back to global
    private func findDerivedData(for projectPath: String) -> String? {
        // Check for local DerivedData (in project directory)
        let localDerivedData = URL(fileURLWithPath: projectPath)
            .appendingPathComponent("DerivedData")
        if fileManager.fileExists(atPath: localDerivedData.path) {
            return localDerivedData.path
        }

        // Check for global DerivedData in ~/Library/Developer/Xcode/DerivedData
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let globalDerivedData = homeDir
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")

        if fileManager.fileExists(atPath: globalDerivedData.path) {
            // Try to find a matching project folder
            // (This is a heuristic - we'd need to parse project name)
            return globalDerivedData.path
        }

        return nil
    }

    /// Find .xcresult bundle in the project
    private func findXCResult(at root: String) -> String? {
        // Check common locations
        let commonPaths = [
            "build/",
            "DerivedData/",
            ".build/"
        ]

        for subpath in commonPaths {
            let searchPath = URL(fileURLWithPath: root).appendingPathComponent(subpath).path
            if let result = findXCResultRecursive(at: searchPath, maxDepth: 3) {
                return result
            }
        }

        // Last resort: search entire project (limit depth to avoid performance issues)
        return findXCResultRecursive(at: root, maxDepth: 2)
    }

    /// Recursively search for .xcresult with depth limit
    private func findXCResultRecursive(at path: String, maxDepth: Int) -> String? {
        guard maxDepth > 0,
              fileManager.fileExists(atPath: path) else {
            return nil
        }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return nil
        }

        // Check current level for .xcresult
        for item in contents {
            if item.hasSuffix(".xcresult") {
                return URL(fileURLWithPath: path).appendingPathComponent(item).path
            }
        }

        // Recurse into subdirectories
        for item in contents {
            let itemPath = URL(fileURLWithPath: path).appendingPathComponent(item).path
            var isDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory),
               isDirectory.boolValue {
                if let result = findXCResultRecursive(at: itemPath, maxDepth: maxDepth - 1) {
                    return result
                }
            }
        }

        return nil
    }
}

// MARK: - Project Information Summary

extension ProjectDetector {
    /// Get a human-readable summary of detected project types
    public func summarize(_ context: ProjectContext) -> String {
        var lines: [String] = []

        lines.append("📂 Project Type Detection")
        lines.append("")

        if context.projectTypes.isEmpty {
            lines.append("  ⚠️  No project types detected")
        } else {
            for type in context.projectTypes {
                lines.append("  ✅ \(type.rawValue)")
            }
        }

        lines.append("")
        lines.append("📦 Artifacts")

        if let derivedData = context.artifacts.derivedDataPath {
            lines.append("  DerivedData: \(derivedData)")
        }

        if let xcresult = context.artifacts.xcresultPath {
            lines.append("  .xcresult: \(xcresult)")
        }

        if context.artifacts.derivedDataPath == nil && context.artifacts.xcresultPath == nil {
            lines.append("  (none found)")
        }

        return lines.joined(separator: "\n")
    }
}
