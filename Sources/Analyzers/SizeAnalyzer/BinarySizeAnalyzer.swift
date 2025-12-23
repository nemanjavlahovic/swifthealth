import Foundation
import Core

/// Analyzes app binary size, framework sizes, and resource bloat
public struct BinarySizeAnalyzer: Analyzer {
    public let id = "size"

    public init() {}

    public func analyze(_ context: ProjectContext, _ config: Config) async -> AnalyzerResult {
        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        // Try to find .app bundle in various locations
        var appPath: String?

        // 1. Look in DerivedData build products
        if let derivedData = context.artifacts.derivedDataPath ?? findDerivedData(in: context.rootPath) {
            appPath = findAppBundle(in: derivedData)
        }

        // 2. Look in build directory
        if appPath == nil {
            let buildDir = (context.rootPath as NSString).appendingPathComponent("build")
            appPath = findAppBundle(in: buildDir)
        }

        // 3. Look for .ipa files
        if appPath == nil {
            appPath = findIPA(in: context.rootPath)
        }

        if let path = appPath {
            let result = await analyzeAppBundle(at: path)
            metrics.append(contentsOf: result.metrics)
            diagnostics.append(contentsOf: result.diagnostics)
        } else {
            diagnostics.append(Diagnostic(
                level: .info,
                message: "No app bundle found for size analysis",
                hint: "Build the project first or provide --app-path"
            ))
        }

        // Also analyze Swift package build products if this is an SPM project
        if context.has(.spm) {
            let spmResult = analyzeSPMProducts(at: context.rootPath)
            metrics.append(contentsOf: spmResult.metrics)
            diagnostics.append(contentsOf: spmResult.diagnostics)
        }

        return AnalyzerResult(metrics: metrics, diagnostics: diagnostics)
    }

    // MARK: - App Bundle Analysis

    private func analyzeAppBundle(at path: String) async -> AnalyzerResult {
        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        let fm = FileManager.default
        let appName = (path as NSString).lastPathComponent

        // Total app size
        if let totalSize = directorySize(at: path) {
            let sizeMB = Double(totalSize) / (1024 * 1024)
            metrics.append(Metric(
                id: "size.total",
                title: "Total App Size",
                category: .build,
                value: .double(sizeMB),
                unit: "MB"
            ))

            if sizeMB > 200 {
                diagnostics.append(Diagnostic(
                    level: .warning,
                    message: "App is \(String(format: "%.1f", sizeMB))MB which may impact download times",
                    hint: "Consider asset optimization and on-demand resources"
                ))
            } else if sizeMB > 100 {
                diagnostics.append(Diagnostic(
                    level: .info,
                    message: "App size is \(String(format: "%.1f", sizeMB))MB"
                ))
            }
        }

        // Main executable size
        let executableName = String(appName.dropLast(4)) // Remove .app
        let executablePath = (path as NSString).appendingPathComponent(executableName)

        if let execSize = fileSize(at: executablePath) {
            let sizeMB = Double(execSize) / (1024 * 1024)
            metrics.append(Metric(
                id: "size.executable",
                title: "Main Executable Size",
                category: .build,
                value: .double(sizeMB),
                unit: "MB"
            ))

            // Analyze executable segments
            let segmentAnalysis = await analyzeExecutableSegments(at: executablePath)
            if !segmentAnalysis.isEmpty {
                metrics.append(Metric(
                    id: "size.segments",
                    title: "Binary Segments",
                    category: .build,
                    value: .string("\(segmentAnalysis.count) segments"),
                    details: [
                        "segments": .array(segmentAnalysis.map { segment in
                            .dictionary([
                                "name": .string(segment.name),
                                "size": .int(Int(segment.size))
                            ])
                        })
                    ]
                ))
            }
        }

        // Frameworks directory
        let frameworksPath = (path as NSString).appendingPathComponent("Frameworks")
        if fm.fileExists(atPath: frameworksPath) {
            let frameworkResult = analyzeFrameworks(at: frameworksPath)
            metrics.append(contentsOf: frameworkResult.metrics)
            diagnostics.append(contentsOf: frameworkResult.diagnostics)
        }

        // Assets catalog
        let assetsPath = (path as NSString).appendingPathComponent("Assets.car")
        if let assetSize = fileSize(at: assetsPath) {
            let sizeMB = Double(assetSize) / (1024 * 1024)
            metrics.append(Metric(
                id: "size.assets",
                title: "Asset Catalog Size",
                category: .build,
                value: .double(sizeMB),
                unit: "MB"
            ))

            if sizeMB > 50 {
                diagnostics.append(Diagnostic(
                    level: .warning,
                    message: "Asset catalog is \(String(format: "%.1f", sizeMB))MB",
                    hint: "Consider compressing images or using on-demand resources"
                ))
            }
        }

        // Resources breakdown
        let resourcesResult = analyzeResources(in: path)
        metrics.append(contentsOf: resourcesResult.metrics)

        return AnalyzerResult(metrics: metrics, diagnostics: diagnostics)
    }

    // MARK: - Framework Analysis

    private func analyzeFrameworks(at path: String) -> AnalyzerResult {
        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return AnalyzerResult(metrics: metrics, diagnostics: diagnostics)
        }

        var frameworkSizes: [(name: String, size: UInt64)] = []
        var totalSize: UInt64 = 0

        for item in contents where item.hasSuffix(".framework") {
            let frameworkPath = (path as NSString).appendingPathComponent(item)
            if let size = directorySize(at: frameworkPath) {
                frameworkSizes.append((name: item, size: size))
                totalSize += size
            }
        }

        // Total frameworks size
        let totalMB = Double(totalSize) / (1024 * 1024)
        metrics.append(Metric(
            id: "size.frameworks",
            title: "Embedded Frameworks Size",
            category: .build,
            value: .double(totalMB),
            unit: "MB",
            details: [
                "count": .int(frameworkSizes.count)
            ]
        ))

        // Sort by size and find largest
        let sortedFrameworks = frameworkSizes.sorted { $0.size > $1.size }

        if let largest = sortedFrameworks.first {
            let sizeMB = Double(largest.size) / (1024 * 1024)
            metrics.append(Metric(
                id: "size.largestFramework",
                title: "Largest Framework",
                category: .build,
                value: .string(largest.name),
                details: [
                    "size": .double(sizeMB)
                ]
            ))

            if sizeMB > 20 {
                diagnostics.append(Diagnostic(
                    level: .info,
                    message: "\(largest.name) is \(String(format: "%.1f", sizeMB))MB",
                    hint: "Consider if all framework features are needed"
                ))
            }
        }

        // List top 5 frameworks
        if sortedFrameworks.count > 1 {
            let top5 = sortedFrameworks.prefix(5).map { framework -> CodableValue in
                .dictionary([
                    "name": .string(framework.name),
                    "sizeMB": .double(Double(framework.size) / (1024 * 1024))
                ])
            }

            metrics.append(Metric(
                id: "size.frameworksBreakdown",
                title: "Framework Breakdown",
                category: .build,
                value: .int(sortedFrameworks.count),
                unit: "frameworks",
                details: [
                    "top": .array(top5)
                ]
            ))
        }

        return AnalyzerResult(metrics: metrics, diagnostics: diagnostics)
    }

    // MARK: - Resource Analysis

    private func analyzeResources(in appPath: String) -> AnalyzerResult {
        var metrics: [Metric] = []

        var imageSize: UInt64 = 0
        var fontSize: UInt64 = 0
        var dataSize: UInt64 = 0
        var otherSize: UInt64 = 0

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: appPath) else {
            return AnalyzerResult(metrics: metrics, diagnostics: [])
        }

        while let file = enumerator.nextObject() as? String {
            let fullPath = (appPath as NSString).appendingPathComponent(file)

            guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                  let size = attrs[.size] as? UInt64 else {
                continue
            }

            let ext = (file as NSString).pathExtension.lowercased()

            switch ext {
            case "png", "jpg", "jpeg", "gif", "webp", "heic", "pdf":
                imageSize += size
            case "ttf", "otf", "ttc", "woff", "woff2":
                fontSize += size
            case "json", "plist", "sqlite", "db", "realm":
                dataSize += size
            case "car", "framework", "dylib", "":
                // Skip these - already counted elsewhere
                break
            default:
                otherSize += size
            }
        }

        // Add resource metrics
        if imageSize > 0 {
            metrics.append(Metric(
                id: "size.images",
                title: "Images Size",
                category: .build,
                value: .double(Double(imageSize) / (1024 * 1024)),
                unit: "MB"
            ))
        }

        if fontSize > 0 {
            metrics.append(Metric(
                id: "size.fonts",
                title: "Fonts Size",
                category: .build,
                value: .double(Double(fontSize) / (1024 * 1024)),
                unit: "MB"
            ))
        }

        if dataSize > 0 {
            metrics.append(Metric(
                id: "size.data",
                title: "Data Files Size",
                category: .build,
                value: .double(Double(dataSize) / (1024 * 1024)),
                unit: "MB"
            ))
        }

        return AnalyzerResult(metrics: metrics, diagnostics: [])
    }

    // MARK: - SPM Products Analysis

    private func analyzeSPMProducts(at projectPath: String) -> AnalyzerResult {
        var metrics: [Metric] = []
        let diagnostics: [Diagnostic] = []

        let buildPath = (projectPath as NSString).appendingPathComponent(".build")

        // Check release build
        let releasePath = (buildPath as NSString).appendingPathComponent("release")
        if let releaseSize = directorySize(at: releasePath) {
            metrics.append(Metric(
                id: "size.spmRelease",
                title: "SPM Release Build Size",
                category: .build,
                value: .double(Double(releaseSize) / (1024 * 1024)),
                unit: "MB"
            ))
        }

        // Check debug build
        let debugPath = (buildPath as NSString).appendingPathComponent("debug")
        if let debugSize = directorySize(at: debugPath) {
            metrics.append(Metric(
                id: "size.spmDebug",
                title: "SPM Debug Build Size",
                category: .build,
                value: .double(Double(debugSize) / (1024 * 1024)),
                unit: "MB"
            ))
        }

        return AnalyzerResult(metrics: metrics, diagnostics: diagnostics)
    }

    // MARK: - Executable Segment Analysis

    private func analyzeExecutableSegments(at path: String) async -> [(name: String, size: UInt64)] {
        var segments: [(name: String, size: UInt64)] = []

        do {
            let result = try await ProcessRunner.run(
                "/usr/bin/size",
                arguments: ["-m", path],
                timeout: 30
            )

            if result.succeeded {
                // Parse size output
                // Format: Segment __TEXT: 1234567
                let lines = result.standardOutput.components(separatedBy: .newlines)

                for line in lines {
                    if line.contains("Segment") {
                        let pattern = #"Segment\s+(\S+):\s*(\d+)"#
                        if let regex = try? NSRegularExpression(pattern: pattern),
                           let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) {
                            if let nameRange = Range(match.range(at: 1), in: line),
                               let sizeRange = Range(match.range(at: 2), in: line) {
                                let name = String(line[nameRange])
                                let size = UInt64(line[sizeRange]) ?? 0
                                segments.append((name: name, size: size))
                            }
                        }
                    }
                }
            }
        } catch {
            // size command not available
        }

        return segments
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

    private func findAppBundle(in directory: String) -> String? {
        guard let enumerator = FileManager.default.enumerator(atPath: directory) else {
            return nil
        }

        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".app") && !file.contains(".dSYM") {
                return (directory as NSString).appendingPathComponent(file)
            }
        }

        return nil
    }

    private func findIPA(in directory: String) -> String? {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            return nil
        }

        for file in contents where file.hasSuffix(".ipa") {
            // Extract IPA and find .app inside
            let ipaPath = (directory as NSString).appendingPathComponent(file)
            // For simplicity, we'll just report the IPA exists
            // Full IPA extraction would require unzipping
            return ipaPath
        }

        return nil
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

    private func fileSize(at path: String) -> UInt64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? UInt64 else {
            return nil
        }
        return size
    }
}
