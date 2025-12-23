import Foundation
import Core

/// Checks package registries online for outdated dependencies
public struct OnlineDependencyChecker {
    private let cacheDirectory: String
    private let cacheMaxAge: TimeInterval = 3600 // 1 hour

    public init(projectPath: String) {
        self.cacheDirectory = (projectPath as NSString).appendingPathComponent(".swifthealth-cache")
    }

    // MARK: - Public API

    /// Check SPM dependencies for updates
    public func checkSPMDependencies(packages: [SPMPackage]) async -> [DependencyStatus] {
        var results: [DependencyStatus] = []

        for package in packages {
            if let status = await checkPackage(package) {
                results.append(status)
            }
        }

        return results
    }

    /// Check CocoaPods dependencies for updates
    public func checkCocoaPodsDependencies(pods: [CocoaPod]) async -> [DependencyStatus] {
        var results: [DependencyStatus] = []

        for pod in pods {
            if let status = await checkPod(pod) {
                results.append(status)
            }
        }

        return results
    }

    // MARK: - SPM Package Checking

    private func checkPackage(_ package: SPMPackage) async -> DependencyStatus? {
        // Check cache first
        if let cached = loadFromCache(key: "spm_\(package.identity)") {
            return cached
        }

        // Extract GitHub owner/repo from URL
        guard let (owner, repo) = parseGitHubURL(package.repositoryURL) else {
            return nil
        }

        // Fetch latest release from GitHub API
        let latestVersion = await fetchGitHubLatestRelease(owner: owner, repo: repo)

        let status = DependencyStatus(
            name: package.identity,
            currentVersion: package.version,
            latestVersion: latestVersion,
            isOutdated: isVersionOutdated(current: package.version, latest: latestVersion),
            source: .spm
        )

        // Cache the result
        saveToCache(key: "spm_\(package.identity)", status: status)

        return status
    }

    private func parseGitHubURL(_ url: String) -> (owner: String, repo: String)? {
        // Match patterns like:
        // https://github.com/owner/repo.git
        // git@github.com:owner/repo.git
        let patterns = [
            #"github\.com[/:]([^/]+)/([^/.]+)"#,
            #"github\.com[/:]([^/]+)/([^/]+)\.git"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: url, options: [], range: NSRange(url.startIndex..., in: url)) else {
                continue
            }

            guard let ownerRange = Range(match.range(at: 1), in: url),
                  let repoRange = Range(match.range(at: 2), in: url) else {
                continue
            }

            let owner = String(url[ownerRange])
            var repo = String(url[repoRange])
            if repo.hasSuffix(".git") {
                repo = String(repo.dropLast(4))
            }

            return (owner, repo)
        }

        return nil
    }

    /// Track rate limit state
    private static var rateLimitRemaining: Int = 60
    private static var rateLimitReset: Date?
    private static var isRateLimited: Bool = false

    private func fetchGitHubLatestRelease(owner: String, repo: String) async -> String? {
        // Check if we're rate limited
        if Self.isRateLimited {
            if let resetDate = Self.rateLimitReset, Date() < resetDate {
                // Still rate limited, skip API call
                return nil
            }
            // Reset time has passed, try again
            Self.isRateLimited = false
        }

        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"

        guard let url = URL(string: urlString) else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }

            // Parse rate limit headers
            if let remaining = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
               let remainingInt = Int(remaining) {
                Self.rateLimitRemaining = remainingInt
            }

            if let reset = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset"),
               let resetTimestamp = Double(reset) {
                Self.rateLimitReset = Date(timeIntervalSince1970: resetTimestamp)
            }

            // Check for rate limit response
            if httpResponse.statusCode == 403 || httpResponse.statusCode == 429 {
                Self.isRateLimited = true
                return nil
            }

            guard httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                return nil
            }

            // Remove 'v' prefix if present
            return tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

        } catch {
            return nil
        }
    }

    /// Check if we're currently rate limited
    public static func getRateLimitStatus() -> (remaining: Int, resetDate: Date?, isLimited: Bool) {
        return (rateLimitRemaining, rateLimitReset, isRateLimited)
    }

    // MARK: - CocoaPods Checking

    private func checkPod(_ pod: CocoaPod) async -> DependencyStatus? {
        // Check cache first
        if let cached = loadFromCache(key: "pod_\(pod.name)") {
            return cached
        }

        // Fetch from CocoaPods trunk API
        let latestVersion = await fetchCocoaPodsLatestVersion(name: pod.name)

        let status = DependencyStatus(
            name: pod.name,
            currentVersion: pod.version,
            latestVersion: latestVersion,
            isOutdated: isVersionOutdated(current: pod.version, latest: latestVersion),
            source: .cocoapods
        )

        // Cache the result
        saveToCache(key: "pod_\(pod.name)", status: status)

        return status
    }

    private func fetchCocoaPodsLatestVersion(name: String) async -> String? {
        let urlString = "https://trunk.cocoapods.org/api/v1/pods/\(name)"

        guard let url = URL(string: urlString) else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let versions = json["versions"] as? [[String: Any]],
                  let latestVersion = versions.first?["name"] as? String else {
                return nil
            }

            return latestVersion

        } catch {
            return nil
        }
    }

    // MARK: - Version Comparison

    private func isVersionOutdated(current: String?, latest: String?) -> Bool {
        guard let current = current, let latest = latest else {
            return false
        }

        return compareVersions(current, latest) == .orderedAscending
    }

    private func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let components1 = v1.split(separator: ".").compactMap { Int($0) }
        let components2 = v2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(components1.count, components2.count)

        for i in 0..<maxLength {
            let c1 = i < components1.count ? components1[i] : 0
            let c2 = i < components2.count ? components2[i] : 0

            if c1 < c2 {
                return .orderedAscending
            } else if c1 > c2 {
                return .orderedDescending
            }
        }

        return .orderedSame
    }

    // MARK: - Caching

    private func loadFromCache(key: String) -> DependencyStatus? {
        let cacheFile = (cacheDirectory as NSString).appendingPathComponent("\(key).json")

        guard FileManager.default.fileExists(atPath: cacheFile) else {
            return nil
        }

        // Check if cache is still valid
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: cacheFile),
              let modDate = attrs[.modificationDate] as? Date else {
            return nil
        }

        if -modDate.timeIntervalSinceNow > cacheMaxAge {
            // Cache expired
            try? FileManager.default.removeItem(atPath: cacheFile)
            return nil
        }

        // Load cached data
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: cacheFile)),
              let status = try? JSONDecoder().decode(DependencyStatus.self, from: data) else {
            return nil
        }

        return status
    }

    private func saveToCache(key: String, status: DependencyStatus) {
        // Ensure cache directory exists
        try? FileManager.default.createDirectory(atPath: cacheDirectory, withIntermediateDirectories: true)

        let cacheFile = (cacheDirectory as NSString).appendingPathComponent("\(key).json")

        guard let data = try? JSONEncoder().encode(status) else {
            return
        }

        try? data.write(to: URL(fileURLWithPath: cacheFile))
    }
}

// MARK: - Supporting Types

/// Status of a dependency after online check
public struct DependencyStatus: Codable {
    public let name: String
    public let currentVersion: String?
    public let latestVersion: String?
    public let isOutdated: Bool
    public let source: DependencySource
}

public enum DependencySource: String, Codable {
    case spm
    case cocoapods
    case carthage
}

/// SPM package info extracted from Package.resolved
public struct SPMPackage {
    public let identity: String
    public let repositoryURL: String
    public let version: String?

    public init(identity: String, repositoryURL: String, version: String?) {
        self.identity = identity
        self.repositoryURL = repositoryURL
        self.version = version
    }
}

/// CocoaPod info extracted from Podfile.lock
public struct CocoaPod {
    public let name: String
    public let version: String?

    public init(name: String, version: String?) {
        self.name = name
        self.version = version
    }
}
