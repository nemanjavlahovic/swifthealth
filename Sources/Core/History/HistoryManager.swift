import Foundation

/// Manages loading, saving, and analyzing health score history
public struct HistoryManager {
    /// Base directory for all SwiftHealth data
    public static let swiftHealthDir = ".swifthealth"

    /// History subdirectory
    public static let historyDir = "history"

    private let projectPath: String
    private let historyFilePath: String

    public init(projectPath: String) {
        self.projectPath = projectPath

        // Store history in ~/.swifthealth/history/<project-hash>.json
        // This avoids polluting project directories
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let baseDir = (homeDir as NSString).appendingPathComponent(Self.swiftHealthDir)
        let historyBaseDir = (baseDir as NSString).appendingPathComponent(Self.historyDir)

        // Create a hash of the project path for the filename
        let projectHash = Self.hashProjectPath(projectPath)
        self.historyFilePath = (historyBaseDir as NSString).appendingPathComponent("\(projectHash).json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            atPath: historyBaseDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    /// Create a stable hash for the project path
    private static func hashProjectPath(_ path: String) -> String {
        // Use a simple hash that's stable across runs
        var hash: UInt64 = 5381
        for char in path.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }
        return String(format: "%016llx", hash)
    }

    // MARK: - Loading

    /// Load history from disk
    public func load() -> HistoryFile? {
        guard FileManager.default.fileExists(atPath: historyFilePath) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: historyFilePath))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(HistoryFile.self, from: data)
        } catch {
            return nil
        }
    }

    /// Load history or create a new empty file
    public func loadOrCreate() -> HistoryFile {
        if let existing = load() {
            return existing
        }
        return HistoryFile(projectPath: projectPath)
    }

    // MARK: - Saving

    /// Save history to disk with file locking to prevent race conditions
    public func save(_ history: HistoryFile) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(history)
        let fileURL = URL(fileURLWithPath: historyFilePath)

        // Use file coordination for safe concurrent access
        // This prevents race conditions when multiple swifthealth processes run simultaneously
        let lockFilePath = historyFilePath + ".lock"

        // Create lock file
        FileManager.default.createFile(atPath: lockFilePath, contents: nil, attributes: nil)

        guard let lockFile = FileHandle(forWritingAtPath: lockFilePath) else {
            // Fallback to atomic write without lock
            try data.write(to: fileURL, options: .atomic)
            return
        }

        defer {
            lockFile.closeFile()
            try? FileManager.default.removeItem(atPath: lockFilePath)
        }

        // Acquire exclusive lock (blocks until available)
        if flock(lockFile.fileDescriptor, LOCK_EX) == 0 {
            defer { flock(lockFile.fileDescriptor, LOCK_UN) }
            try data.write(to: fileURL, options: .atomic)
        } else {
            // Lock failed, try atomic write anyway
            try data.write(to: fileURL, options: .atomic)
        }
    }

    /// Add a new entry to history and save
    public func addEntry(_ entry: HistoryEntry) throws {
        var history = loadOrCreate()

        // Insert new entry at the beginning (newest first)
        history.entries.insert(entry, at: 0)

        // Trim to max entries
        if history.entries.count > HistoryFile.maxEntries {
            history.entries = Array(history.entries.prefix(HistoryFile.maxEntries))
        }

        try save(history)
    }

    /// Create and add an entry from analysis results
    public func recordAnalysis(
        score: Double,
        band: String,
        metrics: [Metric],
        gitCommit: String? = nil,
        gitBranch: String? = nil
    ) throws {
        // Extract metric scores
        var metricScores: [String: Double] = [:]
        for metric in metrics {
            if let score = metric.score {
                metricScores[metric.id] = score
            }
        }

        let entry = HistoryEntry(
            timestamp: Date(),
            score: score,
            band: band,
            gitCommit: gitCommit,
            gitBranch: gitBranch,
            metricScores: metricScores
        )

        try addEntry(entry)
    }

    // MARK: - Analysis

    /// Calculate trend summary from history
    public func calculateTrend() -> TrendSummary {
        guard let history = load(), !history.entries.isEmpty else {
            return TrendSummary()
        }

        let entries = history.entries
        let currentScore = entries.first?.score

        // Delta from last run
        let deltaFromLast: Double? = entries.count >= 2
            ? (currentScore ?? 0) - entries[1].score
            : nil

        // Find entry closest to 7 days ago
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let deltaFrom7Days = findDeltaFrom(date: sevenDaysAgo, currentScore: currentScore, entries: entries)

        // Find entry closest to 30 days ago
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let deltaFrom30Days = findDeltaFrom(date: thirtyDaysAgo, currentScore: currentScore, entries: entries)

        // Calculate statistics
        let scores = entries.map { $0.score }
        let averageScore = scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)
        let bestScore = scores.max()
        let worstScore = scores.min()

        // Determine trend direction based on recent entries
        let direction = calculateDirection(entries: entries)

        return TrendSummary(
            direction: direction,
            deltaFromLast: deltaFromLast,
            deltaFrom7Days: deltaFrom7Days,
            deltaFrom30Days: deltaFrom30Days,
            entryCount: entries.count,
            averageScore: averageScore,
            bestScore: bestScore,
            worstScore: worstScore
        )
    }

    /// Get the last N entries for display
    public func getRecentEntries(count: Int = 10) -> [HistoryEntry] {
        guard let history = load() else { return [] }
        return Array(history.entries.prefix(count))
    }

    // MARK: - Private Helpers

    private func findDeltaFrom(date: Date, currentScore: Double?, entries: [HistoryEntry]) -> Double? {
        guard let current = currentScore else { return nil }

        // Find entry closest to the target date
        let candidates = entries.filter { $0.timestamp <= date }
        guard let closest = candidates.first else { return nil }

        return current - closest.score
    }

    private func calculateDirection(entries: [HistoryEntry]) -> TrendDirection {
        // Need at least 3 entries to determine trend
        guard entries.count >= 3 else {
            return .unknown
        }

        // Look at last 5 entries (or fewer if not available)
        let recentEntries = Array(entries.prefix(5))
        let scores = recentEntries.map { $0.score }

        // Calculate weighted changes (more recent = more weight)
        var weightedChange = 0.0
        var totalWeight = 0.0

        for i in 0..<(scores.count - 1) {
            let change = scores[i] - scores[i + 1]
            let weight = Double(scores.count - i)
            weightedChange += change * weight
            totalWeight += weight
        }

        let avgChange = weightedChange / totalWeight

        // Thresholds for trend determination
        if avgChange > 0.02 {  // >2% improvement
            return .improving
        } else if avgChange < -0.02 {  // >2% decline
            return .declining
        } else {
            return .stable
        }
    }

    // MARK: - Git Integration

    /// Get current git commit hash
    public static func getCurrentCommit(at path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--short", "HEAD"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return output?.isEmpty == false ? output : nil
        } catch {
            return nil
        }
    }

    /// Get current git branch name
    public static func getCurrentBranch(at path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return output?.isEmpty == false ? output : nil
        } catch {
            return nil
        }
    }
}

// MARK: - ASCII Trend Chart

extension HistoryManager {
    /// Generate an ASCII chart of recent scores
    public func generateASCIIChart(entries: [HistoryEntry], width: Int = 50, height: Int = 8) -> String {
        guard !entries.isEmpty else {
            return "  No history data available"
        }

        // Reverse entries so oldest is first (left to right)
        let chronological = Array(entries.reversed())

        // Calculate score range
        let scores = chronological.map { Int($0.score * 100) }
        let minScore = max(0, (scores.min() ?? 0) - 10)
        let maxScore = min(100, (scores.max() ?? 100) + 10)
        let range = maxScore - minScore

        // Generate chart rows
        var chart: [[Character]] = Array(repeating: Array(repeating: " ", count: width), count: height)

        // Plot points
        for (index, score) in scores.enumerated() {
            let x = Int(Double(index) / Double(max(1, scores.count - 1)) * Double(width - 1))
            let normalizedScore = Double(score - minScore) / Double(max(1, range))
            let y = height - 1 - Int(normalizedScore * Double(height - 1))

            let safeX = min(width - 1, max(0, x))
            let safeY = min(height - 1, max(0, y))
            chart[safeY][safeX] = "*"
        }

        // Connect points with lines
        for i in 0..<(scores.count - 1) {
            let x1 = Int(Double(i) / Double(max(1, scores.count - 1)) * Double(width - 1))
            let x2 = Int(Double(i + 1) / Double(max(1, scores.count - 1)) * Double(width - 1))

            let score1 = Double(scores[i] - minScore) / Double(max(1, range))
            let score2 = Double(scores[i + 1] - minScore) / Double(max(1, range))

            let y1 = height - 1 - Int(score1 * Double(height - 1))
            let y2 = height - 1 - Int(score2 * Double(height - 1))

            // Draw horizontal line between points
            for x in (min(x1, x2) + 1)..<max(x1, x2) {
                let progress = Double(x - x1) / Double(max(1, x2 - x1))
                let y = y1 + Int(progress * Double(y2 - y1))
                let safeX = min(width - 1, max(0, x))
                let safeY = min(height - 1, max(0, y))
                if chart[safeY][safeX] == " " {
                    chart[safeY][safeX] = "-"
                }
            }
        }

        // Build output with y-axis labels
        var output = ""
        for row in 0..<height {
            let scoreAtRow = maxScore - Int(Double(row) / Double(height - 1) * Double(range))
            let label = String(format: "%3d", scoreAtRow)
            let rowStr = String(chart[row])

            if row == 0 || row == height - 1 || row == height / 2 {
                output += "  \(label) |\(rowStr)\n"
            } else {
                output += "      |\(rowStr)\n"
            }
        }

        // X-axis
        output += "      +" + String(repeating: "-", count: width) + "\n"

        // Date labels
        if let first = chronological.first, let last = chronological.last {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"

            let firstDate = dateFormatter.string(from: first.timestamp)
            let lastDate = dateFormatter.string(from: last.timestamp)

            let spacing = width - firstDate.count - lastDate.count
            output += "       \(firstDate)" + String(repeating: " ", count: max(1, spacing)) + "\(lastDate)\n"
        }

        return output
    }
}
