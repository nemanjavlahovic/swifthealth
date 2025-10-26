import ArgumentParser
import Foundation
import Core

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

        // TODO: Project discovery
        // TODO: Run analyzers
        // TODO: Calculate score
        // TODO: Render output

        // Placeholder output
        print("SwiftHealth v0.1.0")
        print("Analyzing: \(absolutePath)")
        print()
        print("⚠️  Analysis not yet implemented")
        print("✅ Configuration loaded successfully")
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
