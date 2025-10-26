import Foundation
import Core

/// Renders health report as JSON
public struct JSONRenderer {

    public init() {}

    /// Render health report as JSON
    public func render(
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
    let tool: ToolInfo
    let project: ProjectInfo
    let metrics: [Metric]
    let score: Int
    let scoreNormalized: Double
    let band: String
    let diagnostics: [Diagnostic]
    let timestamp: String
}
