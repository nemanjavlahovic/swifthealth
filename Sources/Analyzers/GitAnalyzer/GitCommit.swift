import Foundation

/// Represents a git commit with all relevant information
public struct GitCommit {
    /// Full commit hash
    public let hash: String

    /// Commit subject (first line of message)
    public let subject: String

    /// Commit body (remaining lines)
    public let body: String

    /// Author name
    public let authorName: String

    /// Author email
    public let authorEmail: String

    /// Commit timestamp (Unix epoch)
    public let timestamp: TimeInterval

    /// Complete commit message (subject + body)
    public var fullMessage: String {
        if body.isEmpty {
            return subject
        }
        return subject + "\n\n" + body
    }

    /// Date of commit
    public var date: Date {
        Date(timeIntervalSince1970: timestamp)
    }

    /// Days ago this commit was made
    public func daysAgo(from now: Date = Date()) -> Double {
        now.timeIntervalSince(date) / 86400  // seconds per day
    }

    public init(
        hash: String,
        subject: String,
        body: String,
        authorName: String,
        authorEmail: String,
        timestamp: TimeInterval
    ) {
        self.hash = hash
        self.subject = subject
        self.body = body
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.timestamp = timestamp
    }
}

// MARK: - Parsing

extension GitCommit {
    /// Parse a git log line in format: hash|subject|body|authorName|authorEmail|timestamp
    public static func parse(from line: String) -> GitCommit? {
        let parts = line.split(separator: "|", maxSplits: 5, omittingEmptySubsequences: false)

        guard parts.count == 6 else {
            return nil
        }

        let hash = String(parts[0])
        let subject = String(parts[1])
        let body = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
        let authorName = String(parts[3])
        let authorEmail = String(parts[4])

        guard let timestamp = TimeInterval(parts[5]) else {
            return nil
        }

        return GitCommit(
            hash: hash,
            subject: subject,
            body: body,
            authorName: authorName,
            authorEmail: authorEmail,
            timestamp: timestamp
        )
    }
}

// MARK: - Commit Message Quality Analysis

extension GitCommit {
    /// Conventional commit types
    public static let conventionalTypes = [
        "feat", "fix", "docs", "style", "refactor",
        "perf", "test", "build", "ci", "chore", "revert"
    ]

    /// Check if subject follows conventional commit format
    public var isConventionalCommit: Bool {
        // Pattern: type(scope)?: subject
        let pattern = "^(\\w+)(\\([\\w-]+\\))?:"
        return subject.range(of: pattern, options: .regularExpression) != nil
    }

    /// Extract the commit type (e.g., "feat", "fix")
    public var commitType: String? {
        let pattern = "^(\\w+)(\\([\\w-]+\\))?:"
        guard let range = subject.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        let match = subject[range]
        // Extract just the type part before ( or :
        if let colonIndex = match.firstIndex(of: ":") {
            let typeWithMaybeScope = match[..<colonIndex]
            if let parenIndex = typeWithMaybeScope.firstIndex(of: "(") {
                return String(typeWithMaybeScope[..<parenIndex])
            }
            return String(typeWithMaybeScope)
        }

        return nil
    }

    /// Check if commit type is valid conventional commit type
    public var hasValidConventionalType: Bool {
        guard let type = commitType else { return false }
        return Self.conventionalTypes.contains(type)
    }

    /// Subject length (excluding type prefix)
    public var subjectLength: Int {
        subject.count
    }

    /// Check if subject is within recommended length (50 chars)
    public var hasGoodSubjectLength: Bool {
        let length = subjectLength
        return length > 10 && length <= 72  // Minimum 10, max 72
    }

    /// Check if commit has a body (for non-trivial commits)
    public var hasBody: Bool {
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Check if commit references an issue (e.g., #123, Closes #456)
    public var referencesIssue: Bool {
        let pattern = "#\\d+|Closes #\\d+|Fixes #\\d+|Resolves #\\d+"
        return fullMessage.range(of: pattern, options: .regularExpression) != nil
    }

    /// Check if this is a likely "WIP" or low-quality commit
    public var isLowQualityCommit: Bool {
        let lowQualityPatterns = [
            "^wip",
            "^tmp",
            "^temp",
            "^fix$",
            "^update$",
            "^changes$",
            "^stuff$",
            "^asdf",
            "^test$",
            "^merge",
            "^Merge branch"
        ]

        let subjectLower = subject.lowercased()
        return lowQualityPatterns.contains { pattern in
            subjectLower.range(of: pattern, options: .regularExpression) != nil
        }
    }

    /// Calculate a quality score for this commit message (0.0 to 1.0)
    public var messageQualityScore: Double {
        var score = 0.0

        // Base score
        score += 0.2

        // Conventional commit format (+30%)
        if isConventionalCommit && hasValidConventionalType {
            score += 0.3
        }

        // Good subject length (+20%)
        if hasGoodSubjectLength {
            score += 0.2
        }

        // Has body for documentation (+15%)
        if hasBody {
            score += 0.15
        }

        // References issue (+15%)
        if referencesIssue {
            score += 0.15
        }

        // Penalty for low quality (-50%)
        if isLowQualityCommit {
            score -= 0.5
        }

        return max(0, min(1, score))  // Clamp to [0, 1]
    }
}

// MARK: - Merge Commit Detection

extension GitCommit {
    /// Check if this is a merge commit
    public var isMergeCommit: Bool {
        subject.hasPrefix("Merge ") || subject.hasPrefix("Merge branch")
    }

    /// Check if this is a squash merge
    public var isSquashMerge: Bool {
        subject.contains("(#") && subject.contains(")")  // e.g., "feat: xyz (#123)"
    }
}
