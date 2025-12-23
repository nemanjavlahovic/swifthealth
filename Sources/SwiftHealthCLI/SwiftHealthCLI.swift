import ArgumentParser
import Foundation

@main
struct SwiftHealthCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swifthealth",
        abstract: "Analyze the health of Swift/iOS projects",
        version: "0.2.0",
        subcommands: [
            AnalyzeCommand.self,
            InitCommand.self,
            ExplainCommand.self,
            HistoryCommand.self,
        ],
        defaultSubcommand: AnalyzeCommand.self
    )
}
