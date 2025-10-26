import ArgumentParser
import Foundation

struct ExplainCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "explain",
        abstract: "Explain how a metric is calculated and how to improve it"
    )

    @Argument(help: "The metric ID to explain (e.g., 'git.recency', 'deps.outdated')")
    var metricId: String

    func run() throws {
        print("📖 Metric: \(metricId)")
        print()

        // Lookup metric explanation
        guard let explanation = MetricExplanations.get(metricId) else {
            print("❌ Unknown metric: \(metricId)")
            print()
            print("Available metrics:")
            for id in MetricExplanations.allMetricIds {
                print("  - \(id)")
            }
            throw ExitCode.failure
        }

        print("📊 \(explanation.title)")
        print()
        print("Description:")
        print(explanation.description.indented())
        print()
        print("How it's calculated:")
        print(explanation.calculation.indented())
        print()
        print("How to improve:")
        print(explanation.improvements.indented())
    }
}

// Metric explanations database
struct MetricExplanations {
    struct Explanation {
        let title: String
        let description: String
        let calculation: String
        let improvements: String
    }

    static let explanations: [String: Explanation] = [
        "git.recency": Explanation(
            title: "Last Commit Recency",
            description: "Measures how recently the repository has been updated. Active projects should have recent commits.",
            calculation: "Days since the last commit in the repository. Uses 'git log -1 --format=%ct' to get the timestamp of the most recent commit.",
            improvements: """
            - Make regular commits to keep the codebase active
            - Set up automated commits for dependency updates
            - Ensure the team is committing frequently
            - Check if the project is in maintenance mode
            """
        ),
        "git.contributors30d": Explanation(
            title: "Active Contributors (30 days)",
            description: "Number of unique contributors in the last 30 days. More contributors generally indicates a healthier project.",
            calculation: "Count of unique email addresses from 'git shortlog -sne --since=30.days HEAD'",
            improvements: """
            - Encourage team participation
            - Review onboarding process for new contributors
            - Ensure contributors are using consistent email addresses
            - Consider if low contributor count is intentional (small team)
            """
        ),
        "deps.outdated": Explanation(
            title: "Outdated Dependencies",
            description: "Percentage of dependencies that have newer versions available. Outdated dependencies can contain security vulnerabilities and miss bug fixes.",
            calculation: "For SPM, CocoaPods, and Carthage: compares current locked versions against latest available versions. In offline mode, uses age-based heuristics.",
            improvements: """
            - Regularly update dependencies (weekly or monthly)
            - Use 'swift package update' for SPM dependencies
            - Use 'pod update' for CocoaPods dependencies
            - Review changelogs before updating
            - Set up automated dependency update PRs
            """
        ),
        "lint.warnings": Explanation(
            title: "Lint Warnings",
            description: "Number of SwiftLint warnings. While not errors, warnings can indicate code quality issues.",
            calculation: "Runs 'swiftlint lint --reporter json' and counts warnings by severity.",
            improvements: """
            - Fix warnings incrementally (target highest-frequency rules first)
            - Add SwiftLint to CI to prevent new warnings
            - Customize .swiftlint.yml to match team standards
            - Disable rules that don't fit your project (with team agreement)
            """
        ),
        "lint.errors": Explanation(
            title: "Lint Errors",
            description: "Number of SwiftLint errors. These are critical code quality issues that should be fixed.",
            calculation: "Runs 'swiftlint lint --reporter json' and counts errors by severity.",
            improvements: """
            - Fix all lint errors immediately
            - Add SwiftLint to pre-commit hooks
            - Run 'swiftlint autocorrect' for auto-fixable issues
            - Review error rules with team
            """
        ),
        "test.coverage": Explanation(
            title: "Test Coverage",
            description: "Percentage of code covered by tests. Higher coverage generally indicates better tested code.",
            calculation: "Extracts coverage from .xcresult bundle using 'xcrun xccov view --report --json'. Requires running tests with code coverage enabled.",
            improvements: """
            - Write tests for uncovered critical paths
            - Enable code coverage in Xcode scheme
            - Set coverage requirements for new code in PRs
            - Focus on testing business logic and edge cases
            - Use 'xccov' to identify uncovered files
            """
        ),
        "build.avgTime": Explanation(
            title: "Average Build Time",
            description: "Average time to build the project. Faster builds improve developer productivity.",
            calculation: "Parses build logs or 'xcodebuild -showBuildTimingSummary' to calculate mean build duration.",
            improvements: """
            - Identify slow compilation files with build timing
            - Modularize large files
            - Use 'whole module optimization' wisely
            - Cache dependencies (SPM, CocoaPods cache)
            - Use distributed build systems if available
            - Profile with Xcode build timeline
            """
        ),
    ]

    static func get(_ id: String) -> Explanation? {
        explanations[id]
    }

    static var allMetricIds: [String] {
        Array(explanations.keys.sorted())
    }
}

// Helper extension for indenting text
extension String {
    func indented(by spaces: Int = 2) -> String {
        let indent = String(repeating: " ", count: spaces)
        return self.split(separator: "\n")
            .map { indent + $0 }
            .joined(separator: "\n")
    }
}
