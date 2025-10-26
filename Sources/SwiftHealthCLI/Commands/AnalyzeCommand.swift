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

        var allMetrics: [Metric] = []
        var allDiagnostics: [Diagnostic] = []

        // Run Git Analyzer
        if context.has(.git) {
            let gitAnalyzer = GitAnalyzer()
            let gitResult = await gitAnalyzer.analyze(context, configuration)
            allMetrics.append(contentsOf: gitResult.metrics)
            allDiagnostics.append(contentsOf: gitResult.diagnostics)

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

        // Run Code Analyzer
        let codeAnalyzer = CodeAnalyzer()
        let codeResult = await codeAnalyzer.analyze(context, configuration)
        allMetrics.append(contentsOf: codeResult.metrics)
        allDiagnostics.append(contentsOf: codeResult.diagnostics)

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

        // Calculate overall health score
        let scoreEngine = ScoreEngine()
        let (normalizedScore, band) = scoreEngine.calculateScore(metrics: allMetrics, config: configuration)
        let healthScore = Int(normalizedScore * 100)

        // Render final summary
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()
        print("🏥 Health Score: \(healthScore)/100 \(band.emoji) (\(band.label))")
        print()

        // Check fail-under threshold
        let threshold = failUnder ?? configuration.ci.failUnder
        if healthScore < threshold {
            print("❌ Score (\(healthScore)) is below threshold (\(threshold))")
            throw ExitCode.failure
        }

        print()

        if verbose {
            print("Configuration:")
            print("  Weights total: \(configuration.weights.total)")
            print("  CI fail-under: \(configuration.ci.failUnder)")
        }

        // Exit code handling
        if let threshold = failUnder {
            print("Threshold: \(threshold) (not yet enforced)")
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
