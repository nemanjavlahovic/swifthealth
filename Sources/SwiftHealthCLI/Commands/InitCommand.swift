import ArgumentParser
import Foundation
import Core

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create a default .swifthealthrc.json configuration file"
    )

    @Option(
        name: .long,
        help: "Directory to create config file in"
    )
    var path: String = "."

    @Flag(
        name: .long,
        help: "Overwrite existing config file"
    )
    var force: Bool = false

    func run() throws {
        let absolutePath = getAbsolutePath(path)
        let configPath = URL(fileURLWithPath: absolutePath)
            .appendingPathComponent(ConfigLoader.defaultFileName)

        // Check if file already exists
        if FileManager.default.fileExists(atPath: configPath.path) && !force {
            print("❌ Config file already exists at: \(configPath.path)")
            print("   Use --force to overwrite")
            throw ExitCode.failure
        }

        // Create default config
        let defaultConfig = Config.default()

        // Save it
        try ConfigLoader.save(defaultConfig, toDirectory: absolutePath)

        print("✅ Created config file: \(configPath.path)")
        print()
        print("You can now customize the weights and thresholds in this file.")
        print("Run 'swifthealth analyze' to analyze your project with these settings.")
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
