import Foundation
import Core

/// Renders beautiful ASCII art components for SwiftHealth
public struct ASCIIRenderer {

    // MARK: - Configuration

    private let colorsEnabled: Bool
    private let terminalWidth: Int

    public init(colorsEnabled: Bool? = nil, terminalWidth: Int = 80) {
        // Respect NO_COLOR environment variable
        if let colorsEnabled = colorsEnabled {
            self.colorsEnabled = colorsEnabled
        } else {
            self.colorsEnabled = ProcessInfo.processInfo.environment["NO_COLOR"] == nil
        }
        self.terminalWidth = terminalWidth
    }

    // MARK: - ANSI Color Codes

    private let colorGreen = "\u{001B}[32m"
    private let colorYellow = "\u{001B}[33m"
    private let colorOrange = "\u{001B}[38;5;208m"
    private let colorRed = "\u{001B}[31m"
    private let colorCyan = "\u{001B}[1;36m"
    private let colorGray = "\u{001B}[90m"
    private let colorReset = "\u{001B}[0m"

    // MARK: - Public Methods

    /// Render a horizontal bar chart
    /// - Parameters:
    ///   - value: Normalized value [0.0, 1.0]
    ///   - width: Bar width in characters
    ///   - filled: Character for filled portion
    ///   - empty: Character for empty portion
    public func horizontalBar(
        value: Double,
        width: Int = 12,
        filled: Character = "█",
        empty: Character = "░"
    ) -> String {
        let clampedValue = min(max(value, 0.0), 1.0)
        let filledCount = Int(Double(width) * clampedValue)
        let emptyCount = width - filledCount

        let filledPart = String(repeating: filled, count: filledCount)
        let emptyPart = String(repeating: empty, count: emptyCount)

        return "[\(filledPart)\(emptyPart)]"
    }

    /// Render health score meter with band indicators
    public func healthScoreMeter(score: Int, band: ScoreBand) -> String {
        let normalizedScore = Double(score) / 100.0

        let lines = [
            box(title: "🏥 HEALTH SCORE", content: [
                "",
                "      0    10   20   30   40   50   60   70   80   90   100   ",
                "      ├────┼────┼────┼────┼────┼────┼────┼────┼────┼────┤    ",
                "      \(renderScoreMeterBar(value: normalizedScore))",
                "      🔴 Poor    🟠 Fair    🟡 Good    🟢 Excellent            ",
                "                                      ▲                         ",
                "                                   \(String(format: "%d", score))/100                       ",
                ""
            ])
        ]

        return lines.joined(separator: "\n")
    }

    /// Render a category analysis box with metrics
    public func categoryBox(
        title: String,
        emoji: String,
        score: Double,
        metrics: [(label: String, value: String, normalized: Double)],
        categoryWeight: Double,
        contribution: Double
    ) -> String {
        // Header line with score
        let headerLine = "│  \(emoji) \(title)\(String(repeating: " ", count: max(0, 65 - emoji.count - title.count)))Score: \(String(format: "%.2f", score)) │"

        // Metric lines
        var lines: [String] = []
        for (label, value, normalized) in metrics {
            let bar = horizontalBar(value: normalized, width: 13)
            let percent = Int(normalized * 100)
            let percentStr = String(format: "%3d%%", percent)

            // Build metric line
            let labelWidth = 25
            let spacing = max(0, labelWidth - label.count)
            let metricLine = "│  \(label)\(String(repeating: " ", count: spacing))\(value) \(bar) \(percentStr)     │"
            lines.append(metricLine)
        }

        // Contribution lines
        let categoryWeightLine = "│  Category Weight: \(String(format: "%.0f%%", categoryWeight * 100))\(String(repeating: " ", count: max(0, 52)))│"
        let contributionLine = "│  Contribution to Final Score: \(String(format: "%.2f", contribution)) points\(String(repeating: " ", count: max(0, 18)))│"

        let boxWidth = 65
        let topBorder = "┌" + String(repeating: "─", count: boxWidth) + "┐"
        let divider = "├" + String(repeating: "─", count: boxWidth) + "┤"
        let bottomBorder = "└" + String(repeating: "─", count: boxWidth) + "┘"

        var output = topBorder
        output += "\n" + headerLine
        output += "\n" + divider
        output += "\n│                                                                 │"

        for line in lines {
            output += "\n" + line
        }

        output += "\n│                                                                 │"
        output += "\n" + categoryWeightLine
        output += "\n" + contributionLine
        output += "\n│                                                                 │"
        output += "\n" + bottomBorder

        return output
    }

    /// Calculate category-level scores from metrics
    public func calculateCategoryScores(
        metrics: [Metric]
    ) -> [(name: String, score: Double)] {
        var categoryScores: [String: (totalScore: Double, count: Int)] = [:]

        for metric in metrics {
            guard let score = metric.score else { continue }

            let categoryName = metric.category.rawValue.uppercased()

            if categoryScores[categoryName] == nil {
                categoryScores[categoryName] = (0.0, 0)
            }

            var (totalScore, count) = categoryScores[categoryName]!
            totalScore += score
            count += 1

            categoryScores[categoryName] = (totalScore, count)
        }

        var results: [(name: String, score: Double)] = []

        for (categoryName, (totalScore, count)) in categoryScores {
            let avgScore = count > 0 ? totalScore / Double(count) : 0.5
            results.append((name: categoryName, score: avgScore))
        }

        // Sort by category name
        return results.sorted { $0.name < $1.name }
    }

    /// Render summary table
    public func summaryTable(
        categories: [(name: String, score: Double, weight: Double, contribution: Double)]
    ) -> String {
        let boxWidth = 66
        let topBorder = "╔" + String(repeating: "═", count: boxWidth) + "╗"
        let divider = "╠" + String(repeating: "═", count: boxWidth) + "╣"
        let bottomBorder = "╚" + String(repeating: "═", count: boxWidth) + "╝"

        var output = topBorder
        output += "\n║" + centeredText("SUMMARY", width: boxWidth) + "║"
        output += "\n" + divider
        output += "\n║" + String(repeating: " ", count: boxWidth) + "║"

        var totalContribution = 0.0
        for (name, score, weight, contribution) in categories {
            let scorePercent = Int(score * 100)
            let weightPercent = Int(weight * 100)
            let bar = horizontalBar(value: score, width: 13)

            let namePadded = name.count < 14 ? name + String(repeating: " ", count: 14 - name.count) : String(name.prefix(14))
            let contribStr = String(format: "%.2f", contribution)
            let line = "║  \(namePadded) \(bar) \(String(format: "%3d", scorePercent))%  •  Weight: \(String(format: "%3d", weightPercent))%  =  \(String(format: "%7s", contribStr))pt ║"

            output += "\n" + line
            totalContribution += contribution
        }

        output += "\n║" + String(repeating: " ", count: boxWidth) + "║"
        output += "\n║" + String(repeating: " ", count: boxWidth) + "║"

        let totalScore = Int(totalContribution)
        let spacePadding = String(repeating: " ", count: 37)
        output += "\n║" + spacePadding + "────────────────    ║"

        let totalContribStr = String(format: "%.2f", totalContribution)
        let totalLine = "║" + String(repeating: " ", count: 24) + "TOTAL = \(totalContribStr)pt ≈ \(String(format: "%3d", totalScore))/100   ║"
        output += "\n" + totalLine

        output += "\n║" + String(repeating: " ", count: boxWidth) + "║"
        output += "\n" + bottomBorder

        return output
    }

    /// Render progress spinner frames
    public func spinnerFrames() -> [String] {
        return [
            "⠋",
            "⠙",
            "⠹",
            "⠸",
            "⠼",
            "⠴",
            "⠦",
            "⠧",
            "⠇",
            "⠏"
        ]
    }

    // MARK: - Private Helpers

    private func renderScoreMeterBar(value: Double) -> String {
        let totalWidth = 60
        let filledWidth = Int(Double(totalWidth) * value)
        let emptyWidth = totalWidth - filledWidth

        let filled = String(repeating: "▓", count: filledWidth)
        let empty = String(repeating: "░", count: emptyWidth)

        let meterLine = "▕\(filled)\(empty)▏"

        // Create the marker line
        let markerPos = Int(Double(totalWidth - 1) * value)
        let markerLine = "▕" + String(repeating: "─", count: markerPos) + "●" + String(repeating: "─", count: totalWidth - markerPos - 1) + "▏"

        return meterLine + "\n      " + markerLine
    }

    private func box(title: String, content: [String]) -> String {
        let boxWidth = 68
        let topBorder = "╔" + String(repeating: "═", count: boxWidth) + "╗"
        let divider = "╠" + String(repeating: "═", count: boxWidth) + "╣"
        let bottomBorder = "╚" + String(repeating: "═", count: boxWidth) + "╝"

        var output = topBorder
        output += "\n║" + centeredText(title, width: boxWidth) + "║"
        output += "\n" + divider

        for line in content {
            let padding = max(0, boxWidth - line.count)
            output += "\n║" + line + String(repeating: " ", count: padding) + "║"
        }

        output += "\n" + bottomBorder

        return output
    }

    private func centeredText(_ text: String, width: Int) -> String {
        let totalPadding = width - text.count
        let leftPadding = totalPadding / 2
        let rightPadding = totalPadding - leftPadding

        return String(repeating: " ", count: leftPadding) + text + String(repeating: " ", count: rightPadding)
    }

    // MARK: - Helper Methods

    private func getMetricWeight(for metricId: String, config: Config) -> Double {
        switch metricId {
        case "git.recency":
            return config.weights.gitRecency
        case "git.contributors30d":
            return config.weights.gitContributors
        case "git.message.quality", "git.message.conventional":
            return config.weights.gitRecency * 0.5
        case "code.comments.density", "code.files.avgSize":
            return config.weights.codeLOC * 0.5
        case "lint.warnings":
            return config.weights.lintWarnings
        case "lint.errors":
            return config.weights.lintErrors
        case "deps.outdated":
            return config.weights.depsOutdated
        case "deps.spm.lockfileAge", "deps.pods.lockfileAge", "deps.carthage.lockfileAge":
            return 0.0
        default:
            return 0.0
        }
    }

    // MARK: - Color Support

    private func applyColor(_ text: String, code: String) -> String {
        guard colorsEnabled else { return text }
        return code + text + colorReset
    }
}
