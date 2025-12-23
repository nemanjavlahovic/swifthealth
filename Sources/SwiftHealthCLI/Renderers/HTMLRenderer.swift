import Foundation
import Core

/// Renders health report as a self-contained HTML file
struct HTMLRenderer {
    private let historyManager: HistoryManager?

    init(projectPath: String? = nil) {
        if let path = projectPath {
            self.historyManager = HistoryManager(projectPath: path)
        } else {
            self.historyManager = nil
        }
    }

    /// Render health report as HTML
    func render(
        metrics: [Metric],
        score: Int,
        band: ScoreBand,
        diagnostics: [Diagnostic],
        projectPath: String,
        projectTypes: [ProjectType]
    ) -> String {
        var html = HTMLTemplate.template

        // Basic replacements
        let projectName = (projectPath as NSString).lastPathComponent
        let timestamp = formatDate(Date())

        html = html.replacingOccurrences(of: "{{PROJECT_NAME}}", with: escapeHTML(projectName))
        html = html.replacingOccurrences(of: "{{PROJECT_PATH}}", with: escapeHTML(projectPath))
        html = html.replacingOccurrences(of: "{{TIMESTAMP}}", with: timestamp)
        html = html.replacingOccurrences(of: "{{VERSION}}", with: "0.1.0")

        // Score
        html = html.replacingOccurrences(of: "{{SCORE}}", with: "\(score)")
        html = html.replacingOccurrences(of: "{{BAND}}", with: bandName(band))
        html = html.replacingOccurrences(of: "{{BAND_LABEL}}", with: band.label)

        // Score gauge offset (264 is full circle, 0 is empty)
        let scoreOffset = Int(264 - (Double(score) / 100.0 * 264))
        html = html.replacingOccurrences(of: "{{SCORE_OFFSET}}", with: "\(scoreOffset)")

        // Summary cards
        let summaryCards = generateSummaryCards(metrics: metrics, score: score, band: band)
        html = html.replacingOccurrences(of: "{{SUMMARY_CARDS}}", with: summaryCards)

        // Trend section
        let trendSection = generateTrendSection()
        html = html.replacingOccurrences(of: "{{TREND_SECTION}}", with: trendSection)

        // Category cards
        let categoryCards = generateCategoryCards(metrics: metrics)
        html = html.replacingOccurrences(of: "{{CATEGORY_CARDS}}", with: categoryCards)

        // Diagnostics
        html = html.replacingOccurrences(of: "{{DIAGNOSTIC_COUNT}}", with: "\(diagnostics.count)")
        let diagnosticsHTML = generateDiagnostics(diagnostics)
        html = html.replacingOccurrences(of: "{{DIAGNOSTICS}}", with: diagnosticsHTML)

        return html
    }

    // MARK: - Summary Cards

    private func generateSummaryCards(metrics: [Metric], score: Int, band: ScoreBand) -> String {
        var cards: [String] = []

        // Overall score
        cards.append(HTMLTemplate.summaryCard(
            value: "\(score)/100",
            label: "Health Score",
            colorClass: "band-\(bandName(band))"
        ))

        // Files analyzed
        if let locMetric = metrics.first(where: { $0.id == "code.loc" }),
           case .int(let loc) = locMetric.value {
            cards.append(HTMLTemplate.summaryCard(
                value: formatNumber(loc),
                label: "Lines of Code"
            ))
        }

        // Dependencies
        let totalDeps = metrics.filter { $0.id.hasPrefix("deps.") && $0.id.hasSuffix(".total") }
            .compactMap { metric -> Int? in
                if case .int(let count) = metric.value { return count }
                return nil
            }.reduce(0, +)
        if totalDeps > 0 {
            cards.append(HTMLTemplate.summaryCard(
                value: "\(totalDeps)",
                label: "Dependencies"
            ))
        }

        // Lint issues
        let warnings = metrics.first(where: { $0.id == "lint.warnings" })
        let errors = metrics.first(where: { $0.id == "lint.errors" })
        var lintCount = 0
        if case .int(let w) = warnings?.value { lintCount += w }
        if case .int(let e) = errors?.value { lintCount += e }

        cards.append(HTMLTemplate.summaryCard(
            value: "\(lintCount)",
            label: "Lint Issues",
            colorClass: lintCount > 0 ? "band-fair" : "band-excellent"
        ))

        return cards.joined(separator: "\n")
    }

    // MARK: - Trend Section

    private func generateTrendSection() -> String {
        guard let manager = historyManager else {
            return ""
        }

        let entries = manager.getRecentEntries(count: 10)
        guard entries.count >= 2 else {
            return ""
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd"

        let chartData = entries.reversed().map { entry in
            (date: dateFormatter.string(from: entry.timestamp), score: entry.scorePercent)
        }

        let chart = HTMLTemplate.trendChart(entries: chartData)

        return """
        <section class="trend-section">
            <div class="trend-chart">
                <h3 class="trend-title">Score Trend (Last \(entries.count) Runs)</h3>
                \(chart)
            </div>
        </section>
        """
    }

    // MARK: - Category Cards

    private func generateCategoryCards(metrics: [Metric]) -> String {
        // Group metrics by category
        var categoryMetrics: [MetricCategory: [Metric]] = [:]

        for metric in metrics {
            if categoryMetrics[metric.category] == nil {
                categoryMetrics[metric.category] = []
            }
            categoryMetrics[metric.category]?.append(metric)
        }

        // Generate cards for each category
        var cards: [String] = []

        let categoryOrder: [MetricCategory] = [.git, .code, .lint, .dependencies, .test, .build]

        for category in categoryOrder {
            guard let categoryMetricsList = categoryMetrics[category], !categoryMetricsList.isEmpty else {
                continue
            }

            let (title, emoji) = categoryInfo(category)

            // Calculate category score (average of metric scores)
            let scores = categoryMetricsList.compactMap { $0.score }
            let avgScore = scores.isEmpty ? 0.5 : scores.reduce(0, +) / Double(scores.count)
            let categoryScore = Int(avgScore * 100)

            // Format metrics for display
            let formattedMetrics = categoryMetricsList.map { metric -> (name: String, value: String, normalized: Double) in
                let valueStr = formatMetricValue(metric)
                let normalized = metric.score ?? 0.5
                return (name: metric.title, value: valueStr, normalized: normalized)
            }

            cards.append(HTMLTemplate.categoryCard(
                title: title,
                emoji: emoji,
                score: categoryScore,
                metrics: formattedMetrics
            ))
        }

        return cards.joined(separator: "\n")
    }

    // MARK: - Diagnostics

    private func generateDiagnostics(_ diagnostics: [Diagnostic]) -> String {
        if diagnostics.isEmpty {
            return "<p style=\"color: var(--color-text-muted);\">No diagnostics to display.</p>"
        }

        return diagnostics.map { diagnostic in
            HTMLTemplate.diagnosticItem(
                level: diagnostic.level.rawValue,
                message: diagnostic.message,
                hint: diagnostic.hint
            )
        }.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func bandName(_ band: ScoreBand) -> String {
        switch band {
        case .excellent: return "excellent"
        case .good: return "good"
        case .fair: return "fair"
        case .poor: return "poor"
        }
    }

    private func categoryInfo(_ category: MetricCategory) -> (title: String, emoji: String) {
        switch category {
        case .git: return ("Git", "G")
        case .code: return ("Code", "C")
        case .lint: return ("Lint", "L")
        case .dependencies: return ("Dependencies", "D")
        case .test: return ("Tests", "T")
        case .build: return ("Build", "B")
        }
    }

    private func formatMetricValue(_ metric: Metric) -> String {
        let unit = metric.unit ?? ""

        switch metric.value {
        case .double(let val):
            return String(format: "%.1f", val) + (unit.isEmpty ? "" : " \(unit)")
        case .int(let val):
            return "\(val)" + (unit.isEmpty ? "" : " \(unit)")
        case .string(let val):
            return val
        case .percent(let val):
            return String(format: "%.1f%%", val * 100)
        case .duration(let val):
            return String(format: "%.2fs", val)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
