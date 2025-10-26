import ArgumentParser
import Foundation

@main
struct SwiftHealthCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swifthealth",
        abstract: "Analyze the health of Swift/iOS projects",
        version: "0.1.0",
        subcommands: [
            AnalyzeCommand.self,
            InitCommand.self,
            ExplainCommand.self,
        ],
        defaultSubcommand: AnalyzeCommand.self
    )
}
