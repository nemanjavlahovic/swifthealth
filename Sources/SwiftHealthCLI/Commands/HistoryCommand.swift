import ArgumentParser
import Foundation
import Core

struct HistoryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "history",
        abstract: "View health score history and trends"
    )

    @Option(
        name: .long,
        help: "Path to the project directory"
    )
    var path: String = "."

    @Option(
        name: .long,
        help: "Number of entries to show"
    )
    var count: Int = 10

    @Flag(
        name: .long,
        help: "Show detailed metric breakdown"
    )
    var verbose: Bool = false

    @Flag(
        name: .long,
        help: "Output as JSON"
    )
    var json: Bool = false

    @Flag(
        name: .long,
        help: "Show ASCII trend chart"
    )
    var chart: Bool = false

    func run() throws {
        // Get absolute path
        let absolutePath = getAbsolutePath(path)

        let manager = HistoryManager(projectPath: absolutePath)

        guard let history = manager.load(), !history.entries.isEmpty else {
            if json {
                print("{\"error\": \"No history found\", \"entries\": []}")
            } else {
                print("No history found for this project.")
                print("Run 'swifthealth analyze' to start tracking health scores.")
            }
            return
        }

        if json {
            printJSONOutput(history: history, manager: manager)
        } else {
            printTextOutput(history: history, manager: manager)
        }
    }

    private func printTextOutput(history: HistoryFile, manager: HistoryManager) {
        let trend = manager.calculateTrend()
        let entries = Array(history.entries.prefix(count))

        // Header
        print()
        print("  SWIFTHEALTH HISTORY")
        print("  " + String(repeating: "=", count: 50))
        print()

        // Trend summary
        print("  Trend: \(trend.direction.description) \(trend.direction.emoji)")
        print()

        if let deltaFromLast = trend.deltaFromLast {
            let sign = deltaFromLast >= 0 ? "+" : ""
            print("  Since last run:    \(sign)\(String(format: "%.1f", deltaFromLast * 100))%")
        }

        if let deltaFrom7Days = trend.deltaFrom7Days {
            let sign = deltaFrom7Days >= 0 ? "+" : ""
            print("  Since 7 days ago:  \(sign)\(String(format: "%.1f", deltaFrom7Days * 100))%")
        }

        if let deltaFrom30Days = trend.deltaFrom30Days {
            let sign = deltaFrom30Days >= 0 ? "+" : ""
            print("  Since 30 days ago: \(sign)\(String(format: "%.1f", deltaFrom30Days * 100))%")
        }

        print()

        // Statistics
        if let avg = trend.averageScore {
            print("  Average score: \(Int(avg * 100))/100")
        }
        if let best = trend.bestScore {
            print("  Best score:    \(Int(best * 100))/100")
        }
        if let worst = trend.worstScore {
            print("  Worst score:   \(Int(worst * 100))/100")
        }
        print("  Total runs:    \(trend.entryCount)")
        print()

        // Chart
        if chart || count >= 5 {
            print("  Recent Trend:")
            print()
            let chartOutput = manager.generateASCIIChart(entries: entries, width: 40, height: 6)
            for line in chartOutput.split(separator: "\n", omittingEmptySubsequences: false) {
                print("  \(line)")
            }
            print()
        }

        // Recent entries table
        print("  Recent History:")
        print("  " + String(repeating: "-", count: 60))
        print("  Date                 Score  Band       Commit   Branch")
        print("  " + String(repeating: "-", count: 60))

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        for entry in entries {
            let dateStr = dateFormatter.string(from: entry.timestamp)
            let scoreStr = String(format: "%3d", entry.scorePercent)
            let bandStr = entry.band.padding(toLength: 10, withPad: " ", startingAt: 0)
            let commitStr = (entry.gitCommit ?? "-").padding(toLength: 8, withPad: " ", startingAt: 0)
            let branchStr = entry.gitBranch ?? "-"

            let bandEmoji = bandEmoji(for: entry.band)
            print("  \(dateStr)   \(scoreStr)  \(bandEmoji) \(bandStr) \(commitStr) \(branchStr)")
        }

        print("  " + String(repeating: "-", count: 60))
        print()

        // Verbose metric breakdown
        if verbose, let latest = entries.first {
            print("  Latest Metric Scores:")
            print("  " + String(repeating: "-", count: 40))

            let sortedMetrics = latest.metricScores.sorted { $0.key < $1.key }
            for (metricId, score) in sortedMetrics {
                let scorePercent = Int(score * 100)
                let bar = renderBar(value: score, width: 15)
                print("  \(metricId.padding(toLength: 25, withPad: " ", startingAt: 0)) \(bar) \(scorePercent)%")
            }
            print()
        }
    }

    private func printJSONOutput(history: HistoryFile, manager: HistoryManager) {
        let trend = manager.calculateTrend()
        let entries = Array(history.entries.prefix(count))

        let output = HistoryOutput(
            projectPath: history.projectPath,
            trend: TrendOutput(
                direction: trend.direction.rawValue,
                deltaFromLast: trend.deltaFromLast,
                deltaFrom7Days: trend.deltaFrom7Days,
                deltaFrom30Days: trend.deltaFrom30Days,
                entryCount: trend.entryCount,
                averageScore: trend.averageScore,
                bestScore: trend.bestScore,
                worstScore: trend.worstScore
            ),
            entries: entries.map { entry in
                EntryOutput(
                    timestamp: ISO8601DateFormatter().string(from: entry.timestamp),
                    score: entry.score,
                    scorePercent: entry.scorePercent,
                    band: entry.band,
                    gitCommit: entry.gitCommit,
                    gitBranch: entry.gitBranch,
                    metricScores: entry.metricScores
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let data = try? encoder.encode(output),
           let jsonStr = String(data: data, encoding: .utf8) {
            print(jsonStr)
        }
    }

    private func getAbsolutePath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        if url.path.hasPrefix("/") {
            return url.path
        } else {
            return FileManager.default.currentDirectoryPath + "/" + url.path
        }
    }

    private func bandEmoji(for band: String) -> String {
        switch band {
        case "green": return "G"
        case "yellow": return "Y"
        case "orange": return "O"
        case "red": return "R"
        default: return "?"
        }
    }

    private func renderBar(value: Double, width: Int) -> String {
        let filled = Int(value * Double(width))
        let empty = width - filled
        return "[" + String(repeating: "#", count: filled) + String(repeating: ".", count: empty) + "]"
    }
}

// MARK: - JSON Output Models

private struct HistoryOutput: Codable {
    let projectPath: String
    let trend: TrendOutput
    let entries: [EntryOutput]
}

private struct TrendOutput: Codable {
    let direction: String
    let deltaFromLast: Double?
    let deltaFrom7Days: Double?
    let deltaFrom30Days: Double?
    let entryCount: Int
    let averageScore: Double?
    let bestScore: Double?
    let worstScore: Double?
}

private struct EntryOutput: Codable {
    let timestamp: String
    let score: Double
    let scorePercent: Int
    let band: String
    let gitCommit: String?
    let gitBranch: String?
    let metricScores: [String: Double]
}
