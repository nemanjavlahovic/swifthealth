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
        help: "Write HTML output to file"
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
        help: "Quiet mode - only output score"
    )
    var quiet: Bool = false

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

        if verbose {
            print("📍 Analyzing project at: \(absolutePath)")
            print("⚙️  Using config: \(config ?? ".swifthealthrc.json (or defaults)")")
            print("🌐 Offline mode: \(offline ? "Yes" : "No")")
            print()
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
            print(detector.summarize(context))
            print()
        }

        // Run analyzers
        // Only show TTY output if not JSON format
        if format != .json {
            print("SwiftHealth v0.1.0")
            print("Analyzing: \(absolutePath)")
            print()

            if context.projectTypes.isEmpty {
                print("⚠️  No project types detected")
                print("   Make sure you're in a Swift/iOS project directory")
            } else {
                print("✅ Detected: \(context.projectTypes.map { $0.rawValue }.joined(separator: ", "))")
            }

            print()
            print("🔍 Running analyzers...")
            print()
        }

        var allMetrics: [Metric] = []
        var allDiagnostics: [Diagnostic] = []

        // Only show progress if not JSON output
        let showProgress = format != .json

        // Run Git Analyzer
        if context.has(.git) {
            let gitAnalyzer = GitAnalyzer()
            let gitResult = await gitAnalyzer.analyze(context, configuration)
            allMetrics.append(contentsOf: gitResult.metrics)
            allDiagnostics.append(contentsOf: gitResult.diagnostics)

            if showProgress {
                print("📊 Git Analysis")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                for metric in gitResult.metrics {
                    printMetric(metric)
                }

                if !gitResult.diagnostics.isEmpty {
                    print()
                    print("⚠️  Diagnostics:")
                    for diagnostic in gitResult.diagnostics {
                        let icon = diagnostic.level == .error ? "❌" : diagnostic.level == .warning ? "⚠️" : "ℹ️"
                        print("  \(icon) \(diagnostic.message)")
                        if let hint = diagnostic.hint {
                            print("     → \(hint)")
                        }
                    }
                }
                print()
            }
        }

        // Run Code Analyzer
        let codeAnalyzer = CodeAnalyzer()
        let codeResult = await codeAnalyzer.analyze(context, configuration)
        allMetrics.append(contentsOf: codeResult.metrics)
        allDiagnostics.append(contentsOf: codeResult.diagnostics)

        if showProgress {
            print("📝 Code Analysis")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            for metric in codeResult.metrics {
                printMetric(metric)
            }

            if !codeResult.diagnostics.isEmpty {
                print()
                print("⚠️  Diagnostics:")
                for diagnostic in codeResult.diagnostics {
                    let icon = diagnostic.level == .error ? "❌" : diagnostic.level == .warning ? "⚠️" : "ℹ️"
                    print("  \(icon) \(diagnostic.message)")
                    if let hint = diagnostic.hint {
                        print("     → \(hint)")
                    }
                }
            }
            print()
        }

        // Run SwiftLint Analyzer
        let lintAnalyzer = SwiftLintAnalyzer()
        let lintResult = await lintAnalyzer.analyze(context, configuration)
        allMetrics.append(contentsOf: lintResult.metrics)
        allDiagnostics.append(contentsOf: lintResult.diagnostics)

        if showProgress && (!lintResult.metrics.isEmpty || !lintResult.diagnostics.isEmpty) {
            print("🔍 Lint Analysis")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            for metric in lintResult.metrics {
                printMetric(metric)
            }

            if !lintResult.diagnostics.isEmpty {
                print()
                print("⚠️  Diagnostics:")
                for diagnostic in lintResult.diagnostics {
                    let icon = diagnostic.level == .error ? "❌" : diagnostic.level == .warning ? "⚠️" : "ℹ️"
                    print("  \(icon) \(diagnostic.message)")
                    if let hint = diagnostic.hint {
                        print("     → \(hint)")
                    }
                }
            }
            print()
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
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print()
            print("🏥 Health Score: \(healthScore)/100 \(band.emoji) (\(band.label))")
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
            if showProgress {
                print("❌ Score (\(healthScore)) is below threshold (\(threshold))")
            }
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

    // Helper to print a metric nicely
    private func printMetric(_ metric: Metric) {
        let valueStr: String
        switch metric.value {
        case .double(let val):
            valueStr = String(format: "%.2f", val)
        case .int(let val):
            valueStr = "\(val)"
        case .string(let val):
            valueStr = val
        case .percent(let val):
            valueStr = String(format: "%.1f%%", val * 100)
        case .duration(let val):
            valueStr = String(format: "%.2fs", val)
        }

        let unitStr = metric.unit.map { " \($0)" } ?? ""
        print("  \(metric.title): \(valueStr)\(unitStr)")
    }
}

// Output format enum
enum OutputFormat: String, ExpressibleByArgument {
    case tty
    case json
    case html

    init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }
}
