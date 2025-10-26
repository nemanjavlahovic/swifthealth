import Foundation
import Core

/// Unified analyzer for all dependency managers (SPM, CocoaPods, Carthage)
public struct DependencyAnalyzer: Analyzer {
    public let id = "dependencies"

    public init() {}

    public func analyze(_ context: ProjectContext, _ config: Config) async -> AnalyzerResult {
        var allMetrics: [Metric] = []
        var allDiagnostics: [Diagnostic] = []

        // Run SPM Analyzer
        let spmAnalyzer = SPMAnalyzer()
        let spmResult = spmAnalyzer.analyze(at: context.rootPath)
        allMetrics.append(contentsOf: spmResult.metrics)
        allDiagnostics.append(contentsOf: spmResult.diagnostics)

        // Run CocoaPods Analyzer
        let podsAnalyzer = CocoaPodsAnalyzer()
        let podsResult = podsAnalyzer.analyze(at: context.rootPath)
        allMetrics.append(contentsOf: podsResult.metrics)
        allDiagnostics.append(contentsOf: podsResult.diagnostics)

        // Run Carthage Analyzer
        let carthageAnalyzer = CarthageAnalyzer()
        let carthageResult = carthageAnalyzer.analyze(at: context.rootPath)
        allMetrics.append(contentsOf: carthageResult.metrics)
        allDiagnostics.append(contentsOf: carthageResult.diagnostics)

        // Aggregate outdated metrics from all sources
        let outdatedMetrics = allMetrics.filter { $0.id == "deps.outdated" }
        if !outdatedMetrics.isEmpty {
            let totalOutdated = outdatedMetrics.reduce(0) { total, metric in
                if case .int(let count) = metric.value {
                    return total + count
                }
                return total
            }

            // Calculate total dependencies across all managers
            let totalDeps = [
                allMetrics.first(where: { $0.id == "deps.spm.total" }),
                allMetrics.first(where: { $0.id == "deps.pods.total" }),
                allMetrics.first(where: { $0.id == "deps.carthage.total" })
            ].compactMap { metric -> Int? in
                if case .int(let count) = metric?.value {
                    return count
                }
                return nil
            }.reduce(0, +)

            let outdatedPercent = totalDeps > 0 ? Double(totalOutdated) / Double(totalDeps) : 0.0

            // Remove individual outdated metrics and add unified one
            allMetrics.removeAll { $0.id == "deps.outdated" }

            if totalDeps > 0 {
                allMetrics.append(Metric(
                    id: "deps.outdated",
                    title: "Potentially Outdated Dependencies",
                    category: .dependencies,
                    value: .int(totalOutdated),
                    unit: "count",
                    details: [
                        "total": .int(totalDeps),
                        "percent": .double(outdatedPercent)
                    ]
                ))
            }
        }

        return AnalyzerResult(metrics: allMetrics, diagnostics: allDiagnostics)
    }
}
