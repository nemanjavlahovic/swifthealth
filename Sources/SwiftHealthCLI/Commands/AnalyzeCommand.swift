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
        help: "Minimum score to pass (0-100). Exits with code 1 if score is below this."
    )
    var failUnder: Int?

    @Flag(
        name: .long,
        help: "Verbose output"
    )
    var verbose: Bool = false

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

        // Override offline setting from CLI flag
        context = ProjectContext(
            rootPath: context.rootPath,
            projectTypes: context.projectTypes,
            offline: offline,
            artifacts: context.artifacts
        )

        if verbose {
            progress.status(detector.summarize(context))
            progress.status("")
        }

        // Initialize renderer
        let asciiRenderer = ASCIIRenderer()

        // Run analyzers
        // Only show TTY output if not JSON format
        if format != .json {
            // Display header banner
            let enabledAnalyzers = context.projectTypes.map { $0.rawValue }
            let banner = asciiRenderer.headerBanner(
                version: "0.1.0",
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

        // Calculate overall health score
        let scoreEngine = ScoreEngine()
        let (enrichedMetrics, normalizedScore, band) = scoreEngine.calculateScore(metrics: allMetrics, config: configuration)
        let healthScore = Int(normalizedScore * 100)

        // Render output based on format
        if format == .json {
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
        } else {
            // TTY output
            print()
            let scoreMeter = asciiRenderer.healthScoreMeter(score: healthScore, band: band)
            print(scoreMeter)
            print()

            if verbose {
                print("Configuration:")
                print("  Weights total: \(configuration.weights.total)")
                print("  CI fail-under: \(configuration.ci.failUnder)")
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
