import Foundation
import Core

/// Renders health report as JSON
struct JSONRenderer {

    init() {}

    // periphery:ignore - Reserved for --format json flag
    /// Render health report as JSON
    func render(
        metrics: [Metric],
        score: Int,
        band: ScoreBand,
        diagnostics: [Diagnostic],
        projectPath: String,
        projectTypes: [ProjectType]
    ) -> String {
        let report = JSONReport(
            tool: ToolInfo(name: "swifthealth", version: "0.1.0"),
            project: ProjectInfo(
                root: projectPath,
                detected: projectTypes
            ),
            metrics: metrics,
            score: score,
            scoreNormalized: Double(score) / 100.0,
            band: band.rawValue,
            diagnostics: diagnostics,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(report),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"error\": \"Failed to encode JSON\"}"
        }

        return json
    }
}

// MARK: - JSON Report Structure

private struct JSONReport: Codable {
    // periphery:ignore - Required for JSON encoding
    let tool: ToolInfo
    // periphery:ignore - Required for JSON encoding
    let project: ProjectInfo
    // periphery:ignore - Required for JSON encoding
    let metrics: [Metric]
    // periphery:ignore - Required for JSON encoding
    let score: Int
    // periphery:ignore - Required for JSON encoding
    let scoreNormalized: Double
    // periphery:ignore - Required for JSON encoding
    let band: String
    // periphery:ignore - Required for JSON encoding
    let diagnostics: [Diagnostic]
    // periphery:ignore - Required for JSON encoding
    let timestamp: String
}
