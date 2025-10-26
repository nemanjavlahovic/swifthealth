import Foundation

/// Loads and validates configuration from file or provides defaults
public struct ConfigLoader {
    /// Default config file name
    public static let defaultFileName = ".swifthealthrc.json"

    /// Load configuration from a path
    /// - Parameter path: Path to the directory containing the config file
    /// - Parameter fileName: Name of the config file (defaults to .swifthealthrc.json)
    /// - Returns: Loaded and validated config, or default config if file doesn't exist
    /// - Throws: ConfigError if file exists but is invalid
    public static func load(
        fromDirectory path: String,
        fileName: String = defaultFileName
    ) throws -> Config {
        let fileURL = URL(fileURLWithPath: path).appendingPathComponent(fileName)

        // If file doesn't exist, return default config
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return Config.default()
        }

        // Read file
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw ConfigError.fileReadError(fileURL.path, error)
        }

        // Decode JSON
        let decoder = JSONDecoder()
        let config: Config
        do {
            config = try decoder.decode(Config.self, from: data)
        } catch {
            throw ConfigError.invalidJSON(fileURL.path, error)
        }

        // Validate
        try validate(config)

        return config
    }

    /// Validate a configuration
    /// - Parameter config: The config to validate
    /// - Throws: ConfigError if validation fails
    public static func validate(_ config: Config) throws {
        // Check version
        guard config.version == 1 else {
            throw ConfigError.unsupportedVersion(config.version)
        }

        // Check weights sum to <= 1.0
        let totalWeight = config.weights.total
        guard totalWeight <= 1.0 else {
            throw ConfigError.invalidWeights(
                "Weights sum to \(totalWeight), but must be <= 1.0"
            )
        }

        // Check all weights are non-negative
        let weightsArray = [
            config.weights.gitRecency,
            config.weights.gitContributors,
            config.weights.depsOutdated,
            config.weights.lintWarnings,
            config.weights.lintErrors,
            config.weights.codeLOC,
            config.weights.codeStructure,
            config.weights.testCoverage,
            config.weights.buildAvgTime
        ]

        for weight in weightsArray {
            guard weight >= 0 else {
                throw ConfigError.invalidWeights("All weights must be non-negative")
            }
        }

        // Validate thresholds make sense (warn < fail for all metrics)
        let thresholds = config.thresholds

        guard thresholds.gitRecencyWarnDays < thresholds.gitRecencyFailDays else {
            throw ConfigError.invalidThresholds(
                "git.recency.days.warn (\(thresholds.gitRecencyWarnDays)) must be < fail (\(thresholds.gitRecencyFailDays))"
            )
        }

        guard thresholds.depsOutdatedWarnPct < thresholds.depsOutdatedFailPct else {
            throw ConfigError.invalidThresholds(
                "deps.outdated.warnPct must be < failPct"
            )
        }

        guard thresholds.lintWarningsWarn < thresholds.lintWarningsFail else {
            throw ConfigError.invalidThresholds(
                "lint.warnings.warn must be < fail"
            )
        }

        guard thresholds.lintErrorsWarn < thresholds.lintErrorsFail else {
            throw ConfigError.invalidThresholds(
                "lint.errors.warn must be < fail"
            )
        }

        // For coverage, higher is better, so fail < warn
        guard thresholds.testCoverageFail < thresholds.testCoverageWarn else {
            throw ConfigError.invalidThresholds(
                "test.coverage.fail (\(thresholds.testCoverageFail)) must be < warn (\(thresholds.testCoverageWarn))"
            )
        }

        guard thresholds.buildAvgTimeWarnSec < thresholds.buildAvgTimeFailSec else {
            throw ConfigError.invalidThresholds(
                "build.avgTime.warnSec must be < failSec"
            )
        }

        // Validate CI settings
        guard (0...100).contains(config.ci.failUnder) else {
            throw ConfigError.invalidCISettings(
                "ci.failUnder must be between 0 and 100, got \(config.ci.failUnder)"
            )
        }
    }

    /// Save a config to file
    /// - Parameters:
    ///   - config: The config to save
    ///   - path: Directory path to save to
    ///   - fileName: Name of the config file
    /// - Throws: ConfigError if write fails
    public static func save(
        _ config: Config,
        toDirectory path: String,
        fileName: String = defaultFileName
    ) throws {
        let fileURL = URL(fileURLWithPath: path).appendingPathComponent(fileName)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data: Data
        do {
            data = try encoder.encode(config)
        } catch {
            throw ConfigError.encodingError(error)
        }

        do {
            try data.write(to: fileURL)
        } catch {
            throw ConfigError.fileWriteError(fileURL.path, error)
        }
    }
}

/// Errors that can occur during config loading/validation
public enum ConfigError: Error, CustomStringConvertible {
    case fileReadError(String, Error)
    case fileWriteError(String, Error)
    case invalidJSON(String, Error)
    case unsupportedVersion(Int)
    case invalidWeights(String)
    case invalidThresholds(String)
    case invalidCISettings(String)
    case encodingError(Error)

    public var description: String {
        switch self {
        case .fileReadError(let path, let error):
            return "Failed to read config file at \(path): \(error.localizedDescription)"
        case .fileWriteError(let path, let error):
            return "Failed to write config file to \(path): \(error.localizedDescription)"
        case .invalidJSON(let path, let error):
            return "Invalid JSON in config file at \(path): \(error.localizedDescription)"
        case .unsupportedVersion(let version):
            return "Unsupported config version: \(version). This tool supports version 1."
        case .invalidWeights(let message):
            return "Invalid weights configuration: \(message)"
        case .invalidThresholds(let message):
            return "Invalid thresholds configuration: \(message)"
        case .invalidCISettings(let message):
            return "Invalid CI settings: \(message)"
        case .encodingError(let error):
            return "Failed to encode config: \(error.localizedDescription)"
        }
    }
}
