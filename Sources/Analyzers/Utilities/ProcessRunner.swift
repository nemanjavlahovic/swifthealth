import Foundation

/// Utility for running shell commands and capturing output
public struct ProcessRunner {

    /// Result of running a process
    public struct ProcessResult {
        public let standardOutput: String
        public let standardError: String
        public let exitCode: Int32

        public var succeeded: Bool {
            exitCode == 0
        }
    }

    /// Run a command and return the result
    /// - Parameters:
    ///   - executable: Path to executable (e.g., "/usr/bin/git")
    ///   - arguments: Command arguments
    ///   - workingDirectory: Directory to run command in
    ///   - timeout: Maximum execution time in seconds (default: 30)
    /// - Returns: ProcessResult with output and exit code
    public static func run(
        _ executable: String,
        arguments: [String],
        workingDirectory: String? = nil,
        timeout: TimeInterval = 30
    ) async throws -> ProcessResult {

        // Create the process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        // Set working directory if provided
        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        // Create pipes for stdout and stderr
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Run the process
        try process.run()

        // Wait for completion with timeout
        let completed = await withCheckedContinuation { continuation in
            // Start timeout timer
            let timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                if process.isRunning {
                    process.terminate()
                }
            }

            // Wait for process to finish
            DispatchQueue.global().async {
                process.waitUntilExit()
                timer.invalidate()
                continuation.resume(returning: true)
            }
        }

        // Read output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: outputData, encoding: .utf8) ?? ""
        let stderr = String(data: errorData, encoding: .utf8) ?? ""

        return ProcessResult(
            standardOutput: stdout,
            standardError: stderr,
            exitCode: process.terminationStatus
        )
    }

    /// Run a git command in a repository
    /// - Parameters:
    ///   - arguments: Git command arguments (e.g., ["log", "-1"])
    ///   - repoPath: Path to git repository
    /// - Returns: ProcessResult
    public static func runGit(
        _ arguments: [String],
        in repoPath: String
    ) async throws -> ProcessResult {
        try await run(
            "/usr/bin/git",
            arguments: arguments,
            workingDirectory: repoPath,
            timeout: 30
        )
    }
}

/// Errors that can occur when running processes
public enum ProcessError: Error, CustomStringConvertible {
    case commandNotFound(String)
    case executionFailed(String, Int32)
    case timeout(String)

    public var description: String {
        switch self {
        case .commandNotFound(let cmd):
            return "Command not found: \(cmd)"
        case .executionFailed(let cmd, let code):
            return "Command '\(cmd)' failed with exit code \(code)"
        case .timeout(let cmd):
            return "Command '\(cmd)' timed out"
        }
    }
}
