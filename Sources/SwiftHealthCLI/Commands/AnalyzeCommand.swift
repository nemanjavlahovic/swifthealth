import ArgumentParser
import Foundation
import Core
import Analyzers

struct AnalyzeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "analyze",
        abstract: "Analyze a Swift/iOS project and produce a health score"
    )

    @Option(
        name: .long,
        help: "Path to the project directory to analyze"
    )
    var path: String = "."

    @Option(
        name: .long,
        help: "Output format"
    )
    var format: OutputFormat = .tty

    @Option(
        name: .long,
        help: "Path to config file"
    )
    var config: String?

    @Flag(
        name: .long,
        help: "Offline mode - no network calls"
    )
    var offline: Bool = false

    @Option(
        name: .long,
        help: "Write JSON output to file"
    )
    var jsonOut: String?

    @Option(
        name: .long,
        help: "Write HTML report to file (default: swifthealth-report.html)"
    )
    var htmlOut: String?

    @Option(
        name: .long,
        help: "Minimum score to pass (0-100). Exits with code 1 if score is below this."
    )
    var failUnder: Int?

    @Flag(
        name: .long,
        help: "Verbose output"
    )
    var verbose: Bool = false

    @Flag(
        name: .long,
        help: "Skip saving to history file"
    )
    var noHistory: Bool = false

    @Option(
        name: .long,
        help: "Path to Xcode build log for build time analysis"
    )
    var buildLog: String?

    @Option(
        name: .long,
        help: "Path to .xcresult bundle for Xcode warnings analysis"
    )
    var xcresult: String?

    @Option(
        name: .long,
        help: "Path to .app bundle for size analysis"
    )
    var appPath: String?

    mutating func run() async throws {
        // Get absolute path
        let absolutePath = getAbsolutePath(path)

        // Load configuration
        let configuration: Config
        if let configPath = config {
            let configURL = URL(fileURLWithPath: getAbsolutePath(configPath))
            configuration = try ConfigLoader.load(
                fromDirectory: configURL.deletingLastPathComponent().path,
                fileName: configURL.lastPathComponent
            )
        } else {
            configuration = try ConfigLoader.load(fromDirectory: absolutePath)
        }

        // Create progress tracker based on output format
        let progress = ProgressTrackerFactory.create(for: format)

        if verbose {
            progress.status("📍 Analyzing project at: \(absolutePath)")
            progress.status("⚙️  Using config: \(config ?? ".swifthealthrc.json (or defaults)")")
            progress.status("🌐 Offline mode: \(offline ? "Yes" : "No")")
            progress.status("")
        }

        // Project discovery
        let detector = ProjectDetector()
        var context = detector.discover(at: absolutePath)

        // Override settings from CLI flags and merge artifacts
        let mergedArtifacts = Artifacts(
            derivedDataPath: context.artifacts.derivedDataPath,
            xcresultPath: xcresult.map { getAbsolutePath($0) } ?? context.artifacts.xcresultPath,
            buildLogsPath: buildLog.map { getAbsolutePath($0) } ?? context.artifacts.buildLogsPath
        )

        context = ProjectContext(
            rootPath: context.rootPath,
            projectTypes: context.projectTypes,
            offline: offline,
            artifacts: mergedArtifacts
        )

        if verbose {
            progress.status(detector.summarize(context))
            progress.status("")
        }

        // Initialize renderer
        let asciiRenderer = ASCIIRenderer()

        // Run analyzers
        // Only show TTY output if not JSON or HTML format
        if format == .tty {
            // Display header banner
            let enabledAnalyzers = context.projectTypes.map { $0.rawValue }
            let banner = asciiRenderer.headerBanner(
                version: "0.2.0",
                path: absolutePath,
                analyzers: enabledAnalyzers
            )
            print(banner)
            print()

            if context.projectTypes.isEmpty {
                print("⚠️  No project types detected")
                print("   Make sure you're in a Swift/iOS project directory")
            }

            print()
            print("🔍 Running analyzers...")
            print()
        }

        var allMetrics: [Metric] = []
        var allDiagnostics: [Diagnostic] = []

        // Run Git Analyzer
        if context.has(.git) {
            progress.startPhase("Git Analysis", emoji: "📊")
            let gitAnalyzer = GitAnalyzer()
            let gitResult = await gitAnalyzer.analyze(context, configuration)
            allMetrics.append(contentsOf: gitResult.metrics)
            allDiagnostics.append(contentsOf: gitResult.diagnostics)
            progress.completePhase(metrics: gitResult.metrics, diagnostics: gitResult.diagnostics, verbose: verbose)
        }

        // Run Code Analyzer
        progress.startPhase("Code Analysis", emoji: "📝")
        let codeAnalyzer = CodeAnalyzer()
        let codeResult = await codeAnalyzer.analyze(context, configuration)
        allMetrics.append(contentsOf: codeResult.metrics)
        allDiagnostics.append(contentsOf: codeResult.diagnostics)
        progress.completePhase(metrics: codeResult.metrics, diagnostics: codeResult.diagnostics, verbose: verbose)

        // Run SwiftLint Analyzer
        let lintAnalyzer = SwiftLintAnalyzer()
        let lintResult = await lintAnalyzer.analyze(context, configuration)
        allMetrics.append(contentsOf: lintResult.metrics)
        allDiagnostics.append(contentsOf: lintResult.diagnostics)

        if !lintResult.metrics.isEmpty || !lintResult.diagnostics.isEmpty {
            progress.startPhase("Lint Analysis", emoji: "🔍")
            progress.completePhase(metrics: lintResult.metrics, diagnostics: lintResult.diagnostics, verbose: verbose)
        }

        // Run Dependency Analyzer
        let depsAnalyzer = DependencyAnalyzer()
        let depsResult = await depsAnalyzer.analyze(context, configuration)
        allMetrics.append(contentsOf: depsResult.metrics)
        allDiagnostics.append(contentsOf: depsResult.diagnostics)

        if !depsResult.metrics.isEmpty || !depsResult.diagnostics.isEmpty {
            progress.startPhase("Dependency Analysis", emoji: "📦")
            progress.completePhase(metrics: depsResult.metrics, diagnostics: depsResult.diagnostics, verbose: verbose)
        }

        // Run Dead Code Analyzer (with spinner - can be slow)
        let deadCodeAnalyzer = DeadCodeAnalyzer()

        // Start spinner for potentially long operation
        await progress.startSpinner("Scanning for dead code (this may take a minute)...")

        let deadCodeResult = await deadCodeAnalyzer.analyze(context, configuration)
        allMetrics.append(contentsOf: deadCodeResult.metrics)
        allDiagnostics.append(contentsOf: deadCodeResult.diagnostics)

        let hasDeadCodeResults = !deadCodeResult.metrics.isEmpty || !deadCodeResult.diagnostics.isEmpty
        progress.stopSpinner(
            success: hasDeadCodeResults,
            message: hasDeadCodeResults ? "Dead code scan complete" : "Dead code scan skipped (periphery not available)"
        )

        if hasDeadCodeResults {
            progress.startPhase("Dead Code Analysis", emoji: "🧹")
            progress.completePhase(metrics: deadCodeResult.metrics, diagnostics: deadCodeResult.diagnostics, verbose: verbose)

            // Show detailed breakdown when verbose is enabled
            if verbose, let metric = deadCodeResult.metrics.first,
               let details = metric.details,
               case let .array(items) = details["items"] {
                printDeadCodeDetails(items)
            }
        }

        // Run Build Time Analyzer (if build log provided or DerivedData available)
        let buildAnalyzer = BuildTimeAnalyzer()
        let buildResult = await buildAnalyzer.analyze(context, configuration)
        allMetrics.append(contentsOf: buildResult.metrics)
        allDiagnostics.append(contentsOf: buildResult.diagnostics)

        if !buildResult.metrics.isEmpty {
            progress.startPhase("Build Time Analysis", emoji: "⏱️")
            progress.completePhase(metrics: buildResult.metrics, diagnostics: buildResult.diagnostics, verbose: verbose)
        }

        // Run Xcode Warnings Analyzer (if xcresult provided)
        let xcodeAnalyzer = XcodeWarningsAnalyzer()
        let xcodeResult = await xcodeAnalyzer.analyze(context, configuration)
        allMetrics.append(contentsOf: xcodeResult.metrics)
        allDiagnostics.append(contentsOf: xcodeResult.diagnostics)

        if !xcodeResult.metrics.isEmpty {
            progress.startPhase("Xcode Warnings Analysis", emoji: "⚠️")
            progress.completePhase(metrics: xcodeResult.metrics, diagnostics: xcodeResult.diagnostics, verbose: verbose)
        }

        // Run Binary Size Analyzer (if app path provided or build products found)
        let sizeAnalyzer = BinarySizeAnalyzer()
        let sizeResult = await sizeAnalyzer.analyze(context, configuration)
        allMetrics.append(contentsOf: sizeResult.metrics)
        allDiagnostics.append(contentsOf: sizeResult.diagnostics)

        if !sizeResult.metrics.isEmpty {
            progress.startPhase("Size Analysis", emoji: "📦")
            progress.completePhase(metrics: sizeResult.metrics, diagnostics: sizeResult.diagnostics, verbose: verbose)
        }

        // Calculate overall health score
        let scoreEngine = ScoreEngine()
        let (enrichedMetrics, normalizedScore, band) = scoreEngine.calculateScore(metrics: allMetrics, config: configuration)
        let healthScore = Int(normalizedScore * 100)

        // History management
        let historyManager = HistoryManager(projectPath: absolutePath)
        let previousTrend = historyManager.calculateTrend()

        // Save to history (unless --no-history flag is set)
        if !noHistory {
            let gitCommit = HistoryManager.getCurrentCommit(at: absolutePath)
            let gitBranch = HistoryManager.getCurrentBranch(at: absolutePath)

            do {
                try historyManager.recordAnalysis(
                    score: normalizedScore,
                    band: band.rawValue,
                    metrics: enrichedMetrics,
                    gitCommit: gitCommit,
                    gitBranch: gitBranch
                )
            } catch {
                // Non-fatal: just log if verbose
                if verbose {
                    progress.status("Warning: Could not save history: \(error.localizedDescription)")
                }
            }
        }

        // Render output based on format
        switch format {
        case .json:
            let renderer = JSONRenderer()
            let jsonOutput = renderer.render(
                metrics: enrichedMetrics,
                score: healthScore,
                band: band,
                diagnostics: allDiagnostics,
                projectPath: absolutePath,
                projectTypes: context.projectTypes
            )

            // Write to file or stdout
            if let outputPath = jsonOut {
                let outputURL = URL(fileURLWithPath: getAbsolutePath(outputPath))
                try jsonOutput.write(to: outputURL, atomically: true, encoding: .utf8)
            } else {
                print(jsonOutput)
            }

        case .html:
            let renderer = HTMLRenderer(projectPath: absolutePath)
            let htmlOutput = renderer.render(
                metrics: enrichedMetrics,
                score: healthScore,
                band: band,
                diagnostics: allDiagnostics,
                projectPath: absolutePath,
                projectTypes: context.projectTypes
            )

            // Determine output path
            let outputPath = htmlOut ?? "swifthealth-report.html"
            let outputURL = URL(fileURLWithPath: getAbsolutePath(outputPath))
            try htmlOutput.write(to: outputURL, atomically: true, encoding: .utf8)
            print("HTML report written to: \(outputURL.path)")

        case .tty:
            // TTY output
            print()
            let scoreMeter = asciiRenderer.healthScoreMeter(score: healthScore, band: band)
            print(scoreMeter)

            // Show trend from previous run
            if let deltaFromLast = previousTrend.deltaFromLast {
                let sign = deltaFromLast >= 0 ? "+" : ""
                let deltaPercent = deltaFromLast * 100
                let trendEmoji = deltaFromLast > 0.02 ? "+" : (deltaFromLast < -0.02 ? "-" : "~")
                print("  \(trendEmoji) \(sign)\(String(format: "%.1f", deltaPercent))% from last run")
            }
            print()

            if verbose {
                print("Configuration:")
                print("  Weights total: \(configuration.weights.total)")
                print("  CI fail-under: \(configuration.ci.failUnder)")
                if previousTrend.entryCount > 0 {
                    print("  History entries: \(previousTrend.entryCount)")
                }
                print()
            }
        }

        // Check fail-under threshold
        let threshold = failUnder ?? configuration.ci.failUnder
        if healthScore < threshold {
            progress.status("❌ Score (\(healthScore)) is below threshold (\(threshold))")
            throw ExitCode.failure
        }
    }

    // Helper to get absolute path
    private func getAbsolutePath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        if url.path.hasPrefix("/") {
            return url.path
        } else {
            return FileManager.default.currentDirectoryPath + "/" + url.path
        }
    }

    private func printDeadCodeDetails(_ items: [CodableValue]) {
        // Group items by kind
        var kindGroups: [String: [(name: String, location: String, filePath: String, lineNumber: String)]] = [:]

        for item in items {
            guard case let .dictionary(itemDict) = item,
                  case let .string(name)? = itemDict["name"],
                  case let .string(kindDesc)? = itemDict["kindDescription"],
                  case let .string(location)? = itemDict["location"],
                  case let .string(filePath)? = itemDict["filePath"],
                  let lineNumber = itemDict["lineNumber"] else {
                continue
            }

            let lineStr: String
            if case let .int(line) = lineNumber {
                lineStr = "\(line)"
            } else if case let .string(line) = lineNumber {
                lineStr = line
            } else {
                lineStr = "?"
            }

            if kindGroups[kindDesc] == nil {
                kindGroups[kindDesc] = []
            }
            kindGroups[kindDesc]?.append((name: name, location: location, filePath: filePath, lineNumber: lineStr))
        }

        // Sort kind groups by count (descending)
        let sortedKinds = kindGroups.sorted { $0.value.count > $1.value.count }

        print()
        print("  📋 Detailed Breakdown:")
        print()

        for (kind, items) in sortedKinds {
            let kindName = kind.capitalized + "s"
            print("    \(kindName) (\(items.count) total):")

            for item in items {
                // Shorten file path for readability
                let shortPath = item.filePath.components(separatedBy: "/").suffix(2).joined(separator: "/")
                print("      • \(item.name)")
                print("        \(shortPath):\(item.lineNumber)")
            }
            print()
        }
    }
}
