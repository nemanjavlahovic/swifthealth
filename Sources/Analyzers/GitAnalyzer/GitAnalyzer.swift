import Foundation
import Core

/// Analyzes git repository health and practices
public struct GitAnalyzer: Analyzer {
    public let id = "git"

    /// Number of commits to analyze for quality metrics
    private let commitsToAnalyze = 100

    public init() {}

    public func analyze(_ context: ProjectContext, _ config: Config) async -> AnalyzerResult {
        guard context.has(.git) else {
            return .unavailable(reason: "Not a git repository")
        }

        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        // 1. Get recent commits
        guard let commits = await fetchRecentCommits(from: context.rootPath, count: commitsToAnalyze) else {
            return .unavailable(reason: "Failed to fetch git commits")
        }

        if commits.isEmpty {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "No commits found in repository"
            ))
            return AnalyzerResult(metrics: [], diagnostics: diagnostics)
        }

        // 2. Last commit recency
        if let lastCommit = commits.first {
            let daysAgo = lastCommit.daysAgo()
            metrics.append(Metric(
                id: "git.recency",
                title: "Last Commit Recency",
                category: .git,
                value: .double(daysAgo),
                unit: "days",
                details: [
                    "hash": .string(String(lastCommit.hash.prefix(7))),
                    "subject": .string(lastCommit.subject),
                    "author": .string(lastCommit.authorName)
                ]
            ))
        }

        // 3. Active contributors (last 30 days)
        let recentCommits = commits.filter { $0.daysAgo() <= 30 }
        let uniqueContributors = Set(recentCommits.map { $0.authorEmail })
        metrics.append(Metric(
            id: "git.contributors30d",
            title: "Active Contributors (30 days)",
            category: .git,
            value: .int(uniqueContributors.count),
            unit: "count",
            details: [
                "contributors": .array(uniqueContributors.sorted().map { .string($0) })
            ]
        ))

        // 4. Commit message quality
        let qualityAnalysis = analyzeCommitMessageQuality(commits)
        metrics.append(contentsOf: qualityAnalysis.metrics)
        diagnostics.append(contentsOf: qualityAnalysis.diagnostics)

        // 5. Branch strategy
        let branchAnalysis = await analyzeBranchStrategy(context.rootPath)
        metrics.append(contentsOf: branchAnalysis.metrics)
        diagnostics.append(contentsOf: branchAnalysis.diagnostics)

        // 6. Merge vs Rebase
        let mergeAnalysis = analyzeMergeStrategy(commits)
        metrics.append(contentsOf: mergeAnalysis.metrics)
        diagnostics.append(contentsOf: mergeAnalysis.diagnostics)

        // 7. Commit frequency
        let frequencyAnalysis = analyzeCommitFrequency(commits)
        metrics.append(contentsOf: frequencyAnalysis.metrics)

        return AnalyzerResult(metrics: metrics, diagnostics: diagnostics)
    }

    // MARK: - Helper Methods

    /// Fetch recent commits from the repository
    private func fetchRecentCommits(from repoPath: String, count: Int) async -> [GitCommit]? {
        do {
            let result = try await ProcessRunner.runGit(
                ["log", "-n", "\(count)", "--format=%H|%s|%b|%an|%ae|%ct", "HEAD"],
                in: repoPath
            )

            guard result.succeeded else {
                return nil
            }

            let commits = result.standardOutput
                .split(separator: "\n")
                .compactMap { GitCommit.parse(from: String($0)) }

            return commits
        } catch {
            return nil
        }
    }

    /// Analyze commit message quality
    private func analyzeCommitMessageQuality(_ commits: [GitCommit]) -> (metrics: [Metric], diagnostics: [Diagnostic]) {
        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        let avgQuality = commits.map { $0.messageQualityScore }.reduce(0, +) / Double(commits.count)

        let conventionalCount = commits.filter { $0.isConventionalCommit && $0.hasValidConventionalType }.count
        let conventionalPercent = Double(conventionalCount) / Double(commits.count)

        let lowQualityCount = commits.filter { $0.isLowQualityCommit }.count
        let lowQualityPercent = Double(lowQualityCount) / Double(commits.count)

        // Average quality score
        metrics.append(Metric(
            id: "git.message.quality",
            title: "Commit Message Quality",
            category: .git,
            value: .percent(avgQuality),
            details: [
                "conventionalCommits": .int(conventionalCount),
                "lowQualityCommits": .int(lowQualityCount)
            ]
        ))

        // Conventional commits percentage
        metrics.append(Metric(
            id: "git.message.conventional",
            title: "Conventional Commits",
            category: .git,
            value: .percent(conventionalPercent),
            unit: "percent",
            details: [
                "count": .int(conventionalCount),
                "total": .int(commits.count)
            ]
        ))

        // Diagnostics
        if lowQualityPercent > 0.3 {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "\(lowQualityCount) low-quality commit messages detected",
                hint: "Consider using conventional commit format: type(scope): subject"
            ))
        }

        if conventionalPercent < 0.5 {
            diagnostics.append(Diagnostic(
                level: .info,
                message: "Only \(Int(conventionalPercent * 100))% of commits follow conventional commit format",
                hint: "See https://www.conventionalcommits.org/"
            ))
        }

        return (metrics, diagnostics)
    }

    /// Analyze branch strategy
    private func analyzeBranchStrategy(_ repoPath: String) async -> (metrics: [Metric], diagnostics: [Diagnostic]) {
        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        // Get all branches
        guard let result = try? await ProcessRunner.runGit(["branch", "-a"], in: repoPath),
              result.succeeded else {
            return ([], [])
        }

        let branches = result.standardOutput
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "* ", with: "") }
            .filter { !$0.contains("HEAD") }

        let branchCount = branches.count

        // Detect strategy
        let hasDevelop = branches.contains { $0.contains("develop") }
        let hasMain = branches.contains { $0 == "main" || $0 == "master" }
        let hasFeatureBranches = branches.filter { $0.contains("feature/") }.count
        let hasReleaseBranches = branches.filter { $0.contains("release/") }.count

        var strategy = "unknown"
        if hasDevelop && hasMain && hasFeatureBranches > 0 {
            strategy = "git-flow"
        } else if hasMain && branchCount <= 5 {
            strategy = "trunk-based"
        } else if hasMain {
            strategy = "feature-branch"
        }

        metrics.append(Metric(
            id: "git.branch.strategy",
            title: "Branch Strategy",
            category: .git,
            value: .string(strategy),
            details: [
                "totalBranches": .int(branchCount),
                "featureBranches": .int(hasFeatureBranches),
                "releaseBranches": .int(hasReleaseBranches),
                "hasDevelop": .bool(hasDevelop)
            ]
        ))

        metrics.append(Metric(
            id: "git.branch.count",
            title: "Total Branches",
            category: .git,
            value: .int(branchCount),
            unit: "count"
        ))

        // Diagnostics
        if branchCount > 20 {
            diagnostics.append(Diagnostic(
                level: .warning,
                message: "High number of branches (\(branchCount))",
                hint: "Consider cleaning up stale branches"
            ))
        }

        return (metrics, diagnostics)
    }

    /// Analyze merge vs rebase strategy
    private func analyzeMergeStrategy(_ commits: [GitCommit]) -> (metrics: [Metric], diagnostics: [Diagnostic]) {
        var metrics: [Metric] = []
        var diagnostics: [Diagnostic] = []

        let mergeCommits = commits.filter { $0.isMergeCommit }.count
        let squashMerges = commits.filter { $0.isSquashMerge }.count
        let linearCommits = commits.count - mergeCommits

        let mergePercent = Double(mergeCommits) / Double(commits.count)

        var strategy = "unknown"
        if mergePercent < 0.05 {
            strategy = "rebase-heavy"
        } else if mergePercent > 0.3 {
            strategy = "merge-heavy"
        } else {
            strategy = "mixed"
        }

        metrics.append(Metric(
            id: "git.merge.strategy",
            title: "Merge Strategy",
            category: .git,
            value: .string(strategy),
            details: [
                "mergeCommits": .int(mergeCommits),
                "squashMerges": .int(squashMerges),
                "linearCommits": .int(linearCommits)
            ]
        ))

        metrics.append(Metric(
            id: "git.merge.percentage",
            title: "Merge Commit Percentage",
            category: .git,
            value: .percent(mergePercent),
            details: [
                "count": .int(mergeCommits),
                "total": .int(commits.count)
            ]
        ))

        // Diagnostics
        if mergePercent > 0.5 {
            diagnostics.append(Diagnostic(
                level: .info,
                message: "High percentage of merge commits (\(Int(mergePercent * 100))%)",
                hint: "Consider using rebase or squash merge for cleaner history"
            ))
        }

        return (metrics, diagnostics)
    }

    /// Analyze commit frequency patterns
    private func analyzeCommitFrequency(_ commits: [GitCommit]) -> (metrics: [Metric], diagnostics: [Diagnostic]) {
        var metrics: [Metric] = []

        guard commits.count > 1 else {
            return ([], [])
        }

        // Calculate average commits per day (last 30 days)
        let recentCommits = commits.filter { $0.daysAgo() <= 30 }
        let commitsPerDay = Double(recentCommits.count) / 30.0

        metrics.append(Metric(
            id: "git.frequency.daily",
            title: "Average Commits Per Day",
            category: .git,
            value: .double(commitsPerDay),
            unit: "commits/day",
            details: [
                "commits30d": .int(recentCommits.count)
            ]
        ))

        // Calculate commit velocity trend (last 7 days vs previous 7 days)
        let last7Days = commits.filter { $0.daysAgo() <= 7 }.count
        let previous7Days = commits.filter { $0.daysAgo() > 7 && $0.daysAgo() <= 14 }.count

        var trend = "stable"
        if last7Days > previous7Days * 2 {
            trend = "increasing"
        } else if last7Days < previous7Days / 2 {
            trend = "decreasing"
        }

        metrics.append(Metric(
            id: "git.frequency.trend",
            title: "Commit Frequency Trend",
            category: .git,
            value: .string(trend),
            details: [
                "last7Days": .int(last7Days),
                "previous7Days": .int(previous7Days)
            ]
        ))

        return (metrics, [])
    }
}
