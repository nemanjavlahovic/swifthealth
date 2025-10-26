import Foundation

/// Calculates overall health score from metrics
public struct ScoreEngine {

    public init() {}

    /// Calculate health score from metrics
    /// - Parameters:
    ///   - metrics: All metrics from analyzers
    ///   - config: Configuration with weights and thresholds
    /// - Returns: Metrics with scores, overall score [0.0, 1.0], and score band
    public func calculateScore(
        metrics: [Metric],
        config: Config
    ) -> (metrics: [Metric], score: Double, band: ScoreBand) {

        var enrichedMetrics: [Metric] = []
        var weightedScores: [(weight: Double, score: Double)] = []

        // Normalize each metric and enrich with score
        for metric in metrics {
            if let normalizedScore = normalize(metric: metric, config: config) {
                // Create new metric with score set
                let enrichedMetric = Metric(
                    id: metric.id,
                    title: metric.title,
                    category: metric.category,
                    value: metric.value,
                    unit: metric.unit,
                    score: normalizedScore,
                    details: metric.details
                )
                enrichedMetrics.append(enrichedMetric)

                // Add to weighted scores if it has weight
                let weight = getWeight(for: metric.id, config: config)
                if weight > 0 {
                    weightedScores.append((weight, normalizedScore))
                }
            } else {
                // Keep metric as-is if we can't normalize it
                enrichedMetrics.append(metric)
            }
        }

        // Calculate weighted average
        guard !weightedScores.isEmpty else {
            return (enrichedMetrics, 0.0, .poor)
        }

        let totalWeight = weightedScores.reduce(0) { $0 + $1.weight }
        let weightedSum = weightedScores.reduce(0) { $0 + ($1.weight * $1.score) }

        let finalScore = totalWeight > 0 ? weightedSum / totalWeight : 0.0
        let band = ScoreBand.from(score: finalScore)

        return (enrichedMetrics, finalScore, band)
    }

    // MARK: - Normalization

    /// Normalize a metric to [0.0, 1.0] score
    private func normalize(metric: Metric, config: Config) -> Double? {
        switch metric.id {
        // Git metrics
        case "git.recency":
            return normalizeGitRecency(metric, config.thresholds)
        case "git.contributors30d":
            return normalizeContributors(metric)
        case "git.message.quality":
            return normalizePercent(metric)
        case "git.message.conventional":
            return normalizePercent(metric)
        case "git.branch.count":
            return normalizeBranchCount(metric)
        case "git.merge.percentage":
            return normalizeMergePercentage(metric)

        // Code metrics
        case "code.comments.density":
            return normalizeCommentDensity(metric)
        case "code.files.avgSize":
            return normalizeFileSize(metric)

        // Lint metrics
        case "lint.warnings":
            return normalizeLintWarnings(metric, config.thresholds)
        case "lint.errors":
            return normalizeLintErrors(metric, config.thresholds)

        default:
            // Unknown metrics default to 0.5 (neutral)
            return 0.5
        }
    }

    /// Get weight for a metric ID
    private func getWeight(for metricId: String, config: Config) -> Double {
        switch metricId {
        case "git.recency":
            return config.weights.gitRecency
        case "git.contributors30d":
            return config.weights.gitContributors
        case "git.message.quality", "git.message.conventional":
            // Split git quality weight between these two
            return config.weights.gitRecency * 0.5
        case "code.comments.density", "code.files.avgSize":
            // Split code weight
            return config.weights.codeLOC * 0.5
        case "lint.warnings":
            return config.weights.lintWarnings
        case "lint.errors":
            return config.weights.lintErrors
        default:
            return 0.0
        }
    }

    // MARK: - Specific Normalizers

    private func normalizeGitRecency(_ metric: Metric, _ thresholds: Thresholds) -> Double {
        guard case .double(let days) = metric.value else { return 0.5 }

        let warnDays = Double(thresholds.gitRecencyWarnDays)
        let failDays = Double(thresholds.gitRecencyFailDays)

        // Perfect score if within warn threshold
        if days <= warnDays {
            return 1.0
        }

        // Linear decay between warn and fail
        if days <= failDays {
            return 1.0 - ((days - warnDays) / (failDays - warnDays)) * 0.5
        }

        // Very old commits - exponential decay
        return max(0.0, 0.5 * exp(-(days - failDays) / 30.0))
    }

    private func normalizeContributors(_ metric: Metric) -> Double {
        guard case .int(let count) = metric.value else { return 0.5 }

        // 1 contributor = 0.5, 5+ = 1.0
        switch count {
        case 0: return 0.0
        case 1: return 0.5
        case 2: return 0.7
        case 3: return 0.8
        case 4: return 0.9
        default: return 1.0  // 5+
        }
    }

    private func normalizePercent(_ metric: Metric) -> Double {
        guard case .percent(let value) = metric.value else { return 0.5 }
        // Already normalized [0, 1]
        return value
    }

    private func normalizeBranchCount(_ metric: Metric) -> Double {
        guard case .int(let count) = metric.value else { return 0.5 }

        // 2-10 branches is ideal
        switch count {
        case 0...1: return 0.3  // Too few
        case 2...10: return 1.0  // Ideal
        case 11...20: return 0.8  // Getting messy
        case 21...50: return 0.5  // Too many
        default: return 0.2  // Way too many
        }
    }

    private func normalizeMergePercentage(_ metric: Metric) -> Double {
        guard case .percent(let pct) = metric.value else { return 0.5 }

        // Lower merge percentage is better (cleaner history)
        // 0% = 1.0, 50%+ = 0.3
        if pct < 0.1 {
            return 1.0
        } else if pct < 0.3 {
            return 0.8
        } else if pct < 0.5 {
            return 0.5
        } else {
            return 0.3
        }
    }

    private func normalizeCommentDensity(_ metric: Metric) -> Double {
        guard case .percent(let density) = metric.value else { return 0.5 }

        // 10-20% comments is ideal
        // Too few = undocumented, too many = over-commented
        if density >= 0.10 && density <= 0.20 {
            return 1.0
        } else if density >= 0.05 && density <= 0.30 {
            return 0.8
        } else if density < 0.05 {
            // Too few comments
            return density / 0.05  // Linear scaling
        } else {
            // Too many comments
            return max(0.3, 1.0 - (density - 0.20) * 2)
        }
    }

    private func normalizeFileSize(_ metric: Metric) -> Double {
        guard case .int(let avgSize) = metric.value else { return 0.5 }

        // 50-200 lines per file is ideal
        switch avgSize {
        case 0..<50: return 0.7  // Too small
        case 50...200: return 1.0  // Ideal
        case 201...500: return 0.7  // Getting large
        case 501...1000: return 0.4  // Too large
        default: return 0.2  // Way too large
        }
    }

    private func normalizeLintWarnings(_ metric: Metric, _ thresholds: Thresholds) -> Double {
        guard case .int(let count) = metric.value else { return 0.5 }

        let warn = Double(thresholds.lintWarningsWarn)
        let fail = Double(thresholds.lintWarningsFail)

        // Perfect score if below warn threshold
        if count == 0 {
            return 1.0
        }

        // Linear decay between warn and fail
        let countDouble = Double(count)
        if countDouble <= warn {
            return 1.0 - (countDouble / warn) * 0.2  // 0-50 warnings: 1.0 -> 0.8
        } else if countDouble <= fail {
            return 0.8 - ((countDouble - warn) / (fail - warn)) * 0.6  // 50-200 warnings: 0.8 -> 0.2
        } else {
            // Beyond fail threshold - exponential decay
            return max(0.0, 0.2 * exp(-(countDouble - fail) / 100.0))
        }
    }

    private func normalizeLintErrors(_ metric: Metric, _ thresholds: Thresholds) -> Double {
        guard case .int(let count) = metric.value else { return 0.5 }

        let warn = Double(thresholds.lintErrorsWarn)
        let fail = Double(thresholds.lintErrorsFail)

        // Errors are more critical than warnings
        if count == 0 {
            return 1.0
        }

        // Steep penalty for any errors
        let countDouble = Double(count)
        if countDouble <= warn {
            return 0.7  // Even 1 error is problematic
        } else if countDouble <= fail {
            return 0.7 - ((countDouble - warn) / (fail - warn)) * 0.5  // 1-10 errors: 0.7 -> 0.2
        } else {
            // Beyond fail threshold - severe penalty
            return max(0.0, 0.2 * exp(-(countDouble - fail) / 5.0))
        }
    }
}
