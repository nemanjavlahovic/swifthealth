import Foundation

/// Embedded HTML template for SwiftHealth reports
struct HTMLTemplate {

    /// The complete HTML template with placeholders
    static let template = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SwiftHealth Report - {{PROJECT_NAME}}</title>
    <style>
        :root {
            --color-excellent: #22c55e;
            --color-good: #eab308;
            --color-fair: #f97316;
            --color-poor: #ef4444;
            --color-bg: #0f172a;
            --color-card: #1e293b;
            --color-text: #f8fafc;
            --color-text-muted: #94a3b8;
            --color-border: #334155;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: var(--color-bg);
            color: var(--color-text);
            line-height: 1.6;
            padding: 2rem;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
        }

        header {
            text-align: center;
            margin-bottom: 3rem;
        }

        h1 {
            font-size: 2.5rem;
            font-weight: 700;
            margin-bottom: 0.5rem;
        }

        .subtitle {
            color: var(--color-text-muted);
            font-size: 1rem;
        }

        .score-section {
            display: flex;
            justify-content: center;
            align-items: center;
            margin-bottom: 3rem;
        }

        .score-gauge {
            position: relative;
            width: 250px;
            height: 250px;
        }

        .score-circle {
            transform: rotate(-90deg);
        }

        .score-bg {
            fill: none;
            stroke: var(--color-border);
            stroke-width: 12;
        }

        .score-progress {
            fill: none;
            stroke-width: 12;
            stroke-linecap: round;
            transition: stroke-dashoffset 1s ease-out;
        }

        .score-text {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            text-align: center;
        }

        .score-value {
            font-size: 3.5rem;
            font-weight: 700;
            line-height: 1;
        }

        .score-label {
            font-size: 1rem;
            color: var(--color-text-muted);
            text-transform: uppercase;
            letter-spacing: 0.1em;
        }

        .band-excellent { color: var(--color-excellent); }
        .band-good { color: var(--color-good); }
        .band-fair { color: var(--color-fair); }
        .band-poor { color: var(--color-poor); }

        .stroke-excellent { stroke: var(--color-excellent); }
        .stroke-good { stroke: var(--color-good); }
        .stroke-fair { stroke: var(--color-fair); }
        .stroke-poor { stroke: var(--color-poor); }

        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }

        .card {
            background: var(--color-card);
            border-radius: 12px;
            padding: 1.5rem;
            border: 1px solid var(--color-border);
        }

        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 1rem;
            padding-bottom: 1rem;
            border-bottom: 1px solid var(--color-border);
        }

        .card-title {
            font-size: 1.1rem;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .card-score {
            font-size: 1.25rem;
            font-weight: 700;
        }

        .metric-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 0.75rem 0;
            border-bottom: 1px solid var(--color-border);
        }

        .metric-row:last-child {
            border-bottom: none;
        }

        .metric-name {
            font-size: 0.9rem;
            color: var(--color-text-muted);
        }

        .metric-value {
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 0.75rem;
        }

        .progress-bar {
            width: 100px;
            height: 6px;
            background: var(--color-border);
            border-radius: 3px;
            overflow: hidden;
        }

        .progress-fill {
            height: 100%;
            border-radius: 3px;
            transition: width 0.5s ease-out;
        }

        .diagnostics {
            margin-top: 2rem;
        }

        .diagnostics-title {
            font-size: 1.25rem;
            font-weight: 600;
            margin-bottom: 1rem;
        }

        .diagnostic-item {
            display: flex;
            align-items: flex-start;
            gap: 0.75rem;
            padding: 1rem;
            background: var(--color-card);
            border-radius: 8px;
            margin-bottom: 0.75rem;
            border-left: 4px solid;
        }

        .diagnostic-error {
            border-left-color: var(--color-poor);
        }

        .diagnostic-warning {
            border-left-color: var(--color-good);
        }

        .diagnostic-info {
            border-left-color: var(--color-text-muted);
        }

        .diagnostic-icon {
            font-size: 1.25rem;
        }

        .diagnostic-content {
            flex: 1;
        }

        .diagnostic-message {
            font-size: 0.95rem;
        }

        .diagnostic-hint {
            font-size: 0.85rem;
            color: var(--color-text-muted);
            margin-top: 0.25rem;
        }

        footer {
            text-align: center;
            margin-top: 3rem;
            padding-top: 2rem;
            border-top: 1px solid var(--color-border);
            color: var(--color-text-muted);
            font-size: 0.875rem;
        }

        footer a {
            color: var(--color-text);
            text-decoration: none;
        }

        footer a:hover {
            text-decoration: underline;
        }

        .trend-section {
            margin-bottom: 2rem;
        }

        .trend-chart {
            background: var(--color-card);
            border-radius: 12px;
            padding: 1.5rem;
            border: 1px solid var(--color-border);
        }

        .trend-title {
            font-size: 1.1rem;
            font-weight: 600;
            margin-bottom: 1rem;
        }

        .summary-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 1rem;
            margin-bottom: 2rem;
        }

        .summary-card {
            background: var(--color-card);
            border-radius: 8px;
            padding: 1rem;
            text-align: center;
            border: 1px solid var(--color-border);
        }

        .summary-value {
            font-size: 1.5rem;
            font-weight: 700;
        }

        .summary-label {
            font-size: 0.8rem;
            color: var(--color-text-muted);
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }

        @media (max-width: 768px) {
            body {
                padding: 1rem;
            }

            h1 {
                font-size: 1.75rem;
            }

            .summary-grid {
                grid-template-columns: repeat(2, 1fr);
            }

            .grid {
                grid-template-columns: 1fr;
            }

            .progress-bar {
                width: 60px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>SwiftHealth Report</h1>
            <p class="subtitle">{{PROJECT_PATH}} &bull; {{TIMESTAMP}}</p>
        </header>

        <section class="score-section">
            <div class="score-gauge">
                <svg class="score-circle" viewBox="0 0 100 100">
                    <circle class="score-bg" cx="50" cy="50" r="42"></circle>
                    <circle class="score-progress stroke-{{BAND}}"
                            cx="50" cy="50" r="42"
                            stroke-dasharray="264"
                            stroke-dashoffset="{{SCORE_OFFSET}}">
                    </circle>
                </svg>
                <div class="score-text">
                    <div class="score-value band-{{BAND}}">{{SCORE}}</div>
                    <div class="score-label">{{BAND_LABEL}}</div>
                </div>
            </div>
        </section>

        <section class="summary-grid">
            {{SUMMARY_CARDS}}
        </section>

        {{TREND_SECTION}}

        <section class="grid">
            {{CATEGORY_CARDS}}
        </section>

        <section class="diagnostics">
            <h2 class="diagnostics-title">Diagnostics ({{DIAGNOSTIC_COUNT}})</h2>
            {{DIAGNOSTICS}}
        </section>

        <footer>
            <p>Generated by <a href="https://github.com/nemanjavlahovic/swifthealth">SwiftHealth</a> v{{VERSION}}</p>
        </footer>
    </div>
</body>
</html>
"""

    /// Generate a summary card HTML
    static func summaryCard(value: String, label: String, colorClass: String = "") -> String {
        return """
        <div class="summary-card">
            <div class="summary-value \(colorClass)">\(value)</div>
            <div class="summary-label">\(label)</div>
        </div>
        """
    }

    /// Generate a category card HTML
    static func categoryCard(title: String, emoji: String, score: Int, metrics: [(name: String, value: String, normalized: Double)]) -> String {
        let bandClass = bandClass(forScore: Double(score) / 100.0)
        var metricsHTML = ""

        for (name, value, normalized) in metrics {
            let progressColor = progressColor(forScore: normalized)
            let width = Int(normalized * 100)
            metricsHTML += """
            <div class="metric-row">
                <span class="metric-name">\(name)</span>
                <span class="metric-value">
                    \(value)
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: \(width)%; background: \(progressColor);"></div>
                    </div>
                </span>
            </div>
            """
        }

        return """
        <div class="card">
            <div class="card-header">
                <span class="card-title">\(emoji) \(title)</span>
                <span class="card-score \(bandClass)">\(score)%</span>
            </div>
            \(metricsHTML)
        </div>
        """
    }

    /// Generate a diagnostic item HTML
    static func diagnosticItem(level: String, message: String, hint: String?) -> String {
        let icon: String
        let levelClass: String

        switch level {
        case "error":
            icon = "X"
            levelClass = "diagnostic-error"
        case "warning":
            icon = "!"
            levelClass = "diagnostic-warning"
        default:
            icon = "i"
            levelClass = "diagnostic-info"
        }

        let hintHTML = hint.map { "<div class=\"diagnostic-hint\">\($0)</div>" } ?? ""

        return """
        <div class="diagnostic-item \(levelClass)">
            <span class="diagnostic-icon">\(icon)</span>
            <div class="diagnostic-content">
                <div class="diagnostic-message">\(escapeHTML(message))</div>
                \(hintHTML)
            </div>
        </div>
        """
    }

    /// Generate trend chart SVG
    static func trendChart(entries: [(date: String, score: Int)], width: Int = 600, height: Int = 150) -> String {
        guard entries.count >= 2 else {
            return "<p style=\"color: var(--color-text-muted);\">Not enough data for trend chart.</p>"
        }

        let padding = 40
        let chartWidth = width - padding * 2
        let chartHeight = height - padding * 2

        // Calculate points
        let minScore = max(0, (entries.map { $0.score }.min() ?? 0) - 10)
        let maxScore = min(100, (entries.map { $0.score }.max() ?? 100) + 10)
        let range = maxScore - minScore

        var points: [(x: Int, y: Int)] = []
        for (index, entry) in entries.enumerated() {
            let x = padding + Int(Double(index) / Double(entries.count - 1) * Double(chartWidth))
            let normalizedScore = Double(entry.score - minScore) / Double(max(1, range))
            let y = padding + chartHeight - Int(normalizedScore * Double(chartHeight))
            points.append((x, y))
        }

        // Build path
        var pathD = "M \(points[0].x) \(points[0].y)"
        for i in 1..<points.count {
            pathD += " L \(points[i].x) \(points[i].y)"
        }

        // Build SVG
        var svg = """
        <svg viewBox="0 0 \(width) \(height)" style="width: 100%; height: auto;">
            <!-- Grid lines -->
            <line x1="\(padding)" y1="\(padding)" x2="\(padding)" y2="\(height - padding)" stroke="var(--color-border)" stroke-width="1"/>
            <line x1="\(padding)" y1="\(height - padding)" x2="\(width - padding)" y2="\(height - padding)" stroke="var(--color-border)" stroke-width="1"/>

            <!-- Y-axis labels -->
            <text x="\(padding - 10)" y="\(padding)" fill="var(--color-text-muted)" font-size="12" text-anchor="end">\(maxScore)</text>
            <text x="\(padding - 10)" y="\(height - padding)" fill="var(--color-text-muted)" font-size="12" text-anchor="end">\(minScore)</text>

            <!-- Line -->
            <path d="\(pathD)" fill="none" stroke="var(--color-excellent)" stroke-width="2"/>

            <!-- Points -->
        """

        for (index, point) in points.enumerated() {
            let entry = entries[index]
            svg += """
                <circle cx="\(point.x)" cy="\(point.y)" r="4" fill="var(--color-excellent)"/>
                <text x="\(point.x)" y="\(height - 10)" fill="var(--color-text-muted)" font-size="10" text-anchor="middle">\(entry.date)</text>
            """
        }

        svg += "</svg>"
        return svg
    }

    // MARK: - Helpers

    private static func bandClass(forScore score: Double) -> String {
        if score >= 0.80 { return "band-excellent" }
        if score >= 0.60 { return "band-good" }
        if score >= 0.40 { return "band-fair" }
        return "band-poor"
    }

    private static func progressColor(forScore score: Double) -> String {
        if score >= 0.80 { return "var(--color-excellent)" }
        if score >= 0.60 { return "var(--color-good)" }
        if score >= 0.40 { return "var(--color-fair)" }
        return "var(--color-poor)"
    }

    /// Escape string for safe HTML text content
    private static func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    /// Escape string for use in HTML attributes (more strict)
    static func escapeHTMLAttribute(_ string: String) -> String {
        return escapeHTML(string)
            .replacingOccurrences(of: "`", with: "&#96;")
            .replacingOccurrences(of: "=", with: "&#61;")
            .replacingOccurrences(of: "\n", with: "&#10;")
            .replacingOccurrences(of: "\r", with: "&#13;")
    }

    /// Escape string for use in JavaScript context
    static func escapeJavaScript(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "</", with: "<\\/")  // Prevent script injection
    }
}
