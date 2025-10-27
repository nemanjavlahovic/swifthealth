# SwiftHealth

A command-line tool for analyzing the health of Swift and iOS projects. SwiftHealth produces a comprehensive 0-100 health score based on code metrics, Git practices, and project structure.

## Why SwiftHealth?

**The Problem**: Teams need a quick, objective way to assess technical debt and code quality in Swift projects. Existing solutions are either too heavyweight (SonarQube requires infrastructure), too narrow (only analyze code, not Git practices), or too opaque (you can't explain how the score is calculated).

**The Solution**: SwiftHealth is a single binary that analyzes your project in seconds and produces:
- A 0-100 health score with clear scoring bands (🟢 Excellent, 🟡 Good, 🟠 Fair, 🔴 Poor)
- Actionable diagnostics with improvement hints
- JSON output for CI/CD integration
- Full transparency into how the score is calculated

**Key Differentiators**:
1. **Git-aware**: Analyzes commit quality, branch strategy, merge patterns - not just code
2. **Fast**: Pure Swift implementation, no external dependencies beyond Git
3. **Transparent**: Every metric has a clear normalization algorithm you can inspect
4. **CI-friendly**: JSON output, exit codes, configurable thresholds
5. **Zero setup**: No servers, no databases, just `swifthealth analyze`

---

## Quick Start

### Installation

#### Option 1: Download Pre-built Binary (Recommended)

```bash
# Download the latest release (universal binary for Intel + Apple Silicon)
curl -L -o swifthealth https://github.com/nemanjavlahovic/swifthealth/releases/latest/download/swifthealth-universal

# Verify checksum (recommended)
curl -L -o checksums.txt https://github.com/nemanjavlahovic/swifthealth/releases/latest/download/checksums.txt
shasum -a 256 -c checksums.txt --ignore-missing

# Make executable and move to PATH
chmod +x swifthealth
sudo mv swifthealth /usr/local/bin/

# Verify installation
swifthealth --version
```

**Apple Silicon only:**
```bash
curl -L -o swifthealth https://github.com/nemanjavlahovic/swifthealth/releases/latest/download/swifthealth-arm64
chmod +x swifthealth
sudo mv swifthealth /usr/local/bin/
```

#### Option 2: Build from Source

```bash
# Clone and build
git clone https://github.com/nemanjavlahovic/swifthealth.git
cd swifthealth
swift build -c release

# Copy binary to PATH
cp .build/release/swifthealth /usr/local/bin/
```

### Basic Usage

```bash
# Analyze current directory
swifthealth analyze

# Analyze specific project
swifthealth analyze --path ~/Projects/MyApp

# JSON output for CI
swifthealth analyze --format json --json-out report.json

# Fail if score below threshold
swifthealth analyze --fail-under 80
```

---

## Example Output

```
SwiftHealth v0.1.0
Analyzing: /Users/dev/MyProject

✅ Detected: git, spm

🔍 Running analyzers...

📊 Git Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Last Commit Recency: 0.30 days
  Active Contributors (30 days): 1 count
  Commit Message Quality: 40.0%
  Conventional Commits: 0.0% percent
  Branch Strategy: trunk-based
  Total Branches: 2 count
  Merge Strategy: rebase-heavy
  Merge Commit Percentage: 0.0%
  Average Commits Per Day: 0.07 commits/day
  Commit Frequency Trend: increasing

⚠️  Diagnostics:
  ℹ️ Only 0% of commits follow conventional commit format
     → See https://www.conventionalcommits.org/

📝 Code Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Total Code Files: 18 files
  Total Lines of Code: 1985 lines
  Comment Density: 14.6%
  Average File Size: 110 lines/file
  Swift Percentage: 100.0%

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🏥 Health Score: 64/100 🔴 (Poor)
```

### JSON Output

```json
{
  "tool": {
    "name": "swifthealth",
    "version": "0.1.0"
  },
  "project": {
    "root": "/Users/dev/MyProject",
    "detected": ["git", "spm"]
  },
  "score": 64,
  "scoreNormalized": 0.64,
  "band": "red",
  "metrics": [
    {
      "id": "git.recency",
      "title": "Last Commit Recency",
      "category": "git",
      "value": {"type": "double", "value": 0.30},
      "unit": "days"
    }
    // ... more metrics
  ],
  "diagnostics": [
    {
      "level": "info",
      "message": "Only 0% of commits follow conventional commit format",
      "hint": "See https://www.conventionalcommits.org/"
    }
  ],
  "timestamp": "2025-10-26T20:03:31Z"
}
```

---

## Features

### 📊 Git Analysis
- **Commit Recency**: Days since last commit (fresher = healthier)
- **Active Contributors**: Unique contributors in last 30 days
- **Commit Message Quality**: Analyzed with 5 quality signals
- **Conventional Commits**: Percentage following conventional format
- **Branch Strategy**: Detects git-flow, trunk-based, feature-branch patterns
- **Merge Strategy**: Analyzes merge vs rebase patterns for clean history
- **Commit Frequency**: Tracks velocity and trends

### 📝 Code Analysis
- **Lines of Code**: Total LOC excluding comments and blanks
- **Comment Density**: Sweet spot is 10-20% (too few or too many both penalized)
- **File Size**: Ideal 50-200 lines per file (encourages modularity)
- **Language Breakdown**: Swift vs Objective-C percentage
- **File Count**: Total source files across project

### 🔍 Lint Analysis (SwiftLint)
- **Warnings**: Count of SwiftLint warnings with top offender rules
- **Errors**: Count of SwiftLint errors (heavily penalized)
- **Graceful Degradation**: Works even if SwiftLint not installed
- **Configuration Detection**: Finds .swiftlint.yml automatically

### 📦 Dependency Analysis
- **SPM**: Parses Package.resolved for Swift Package Manager deps
- **CocoaPods**: Parses Podfile.lock for CocoaPods deps
- **Carthage**: Parses Cartfile.resolved for Carthage deps
- **Outdated Detection**: Flags potentially outdated dependencies (lockfile age-based)
- **Multi-Manager**: Handles projects using multiple dependency managers

### 🎯 Scoring System

SwiftHealth uses **weighted normalization** to calculate the health score:

1. Each metric is normalized to [0.0, 1.0] using domain-specific algorithms:
   - **Git Recency**: Exponential decay after threshold (7 days perfect, 30 days degraded)
   - **Contributors**: Discrete scoring (1 = 0.5, 5+ = 1.0)
   - **Branch Count**: 2-10 ideal, penalizes extremes
   - **Comment Density**: 10-20% sweet spot, penalizes under/over-commenting
   - **File Size**: 50-200 lines optimal, penalizes very large files
   - **Lint Warnings**: Linear decay 0-50 warnings, exponential beyond 200
   - **Lint Errors**: Steep penalty (even 1 error = 0.7 score)
   - **Outdated Deps**: Percentage-based with 10% warn, 30% fail thresholds
   - **Lockfile Age**: Fresh (<30 days) = 1.0, stale (>90 days) exponential decay

2. Each metric has a configurable weight (default weights sum to 1.0):
   - Git Recency: 15%
   - Git Contributors: 10%
   - Dependency Outdated: 35%
   - Lint Warnings: 15%
   - Lint Errors: 15%
   - Code LOC: 10%

3. Final score = weighted average × 100

**Score Bands**:
- 🟢 **Excellent** (80-100): Production-ready, well-maintained
- 🟡 **Good** (60-79): Solid foundation, minor improvements needed
- 🟠 **Fair** (40-59): Technical debt present, needs attention
- 🔴 **Poor** (0-39): Significant issues, immediate action required

---

## Configuration

Create `.swifthealthrc.json` in your project root:

```json
{
  "weights": {
    "git.recency": 0.15,
    "git.contributors30d": 0.10,
    "deps.outdated": 0.35,
    "lint.warnings": 0.15,
    "lint.errors": 0.15,
    "code.loc": 0.10
  },
  "thresholds": {
    "git.recency.days.warn": 7,
    "git.recency.days.fail": 30,
    "deps.outdated.warnPct": 0.10,
    "deps.outdated.failPct": 0.30,
    "lint.warnings.warn": 50,
    "lint.warnings.fail": 200,
    "lint.errors.warn": 1,
    "lint.errors.fail": 10
  },
  "ci": {
    "failUnder": 80
  }
}
```

Generate default config:
```bash
swifthealth init
```

---

## CI/CD Integration

### GitHub Actions

```yaml
name: Health Check
on: [push, pull_request]

jobs:
  health:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install SwiftHealth
        run: |
          curl -L -o swifthealth https://github.com/nemanjavlahovic/swifthealth/releases/latest/download/swifthealth-universal
          chmod +x swifthealth
          sudo mv swifthealth /usr/local/bin/

      - name: Run Health Check
        run: |
          swifthealth analyze --format json --json-out health.json --fail-under 70

      - name: Upload Report
        uses: actions/upload-artifact@v4
        with:
          name: health-report
          path: health.json
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

score=$(swifthealth analyze --format json | jq -r '.score')

if [ "$score" -lt 60 ]; then
  echo "❌ Health score ($score) is below minimum (60)"
  echo "Run 'swifthealth analyze --verbose' for details"
  exit 1
fi

echo "✅ Health score: $score"
```

---

## Architecture

SwiftHealth is built with a **modular, protocol-oriented architecture** using Swift Package Manager:

### Package Structure

```
SwiftHealth/
├── Sources/
│   ├── Core/              # Shared models and utilities
│   │   ├── Models/        # Metric, Config, AnalyzerResult
│   │   ├── Config/        # ConfigLoader with validation
│   │   └── Scoring/       # ScoreEngine with normalization
│   ├── Analyzers/         # Analysis implementations
│   │   ├── GitAnalyzer/   # Git metrics via Process API
│   │   └── CodeAnalyzer/  # LOC counting, file scanning
│   └── SwiftHealthCLI/    # CLI entry point
│       ├── Commands/      # ArgumentParser commands
│       └── Renderers/     # TTY and JSON output
└── Package.swift
```

### Key Design Decisions

1. **Protocol-Oriented Design**: `Analyzer` protocol enables easy extension
2. **Value Types**: Structs for all data models (immutability, thread-safety)
3. **Async/await**: Modern concurrency for running multiple analyzers
4. **Process API**: Direct Git command execution (no libgit2 dependency)
5. **Codable Everywhere**: Automatic JSON serialization with custom CodingKeys
6. **Weighted Scoring**: Pluggable normalization algorithms per metric type

### Adding a New Analyzer

```swift
import Core

public struct TestCoverageAnalyzer: Analyzer {
    public let id = "test-coverage"

    public init() {}

    public func analyze(_ context: ProjectContext, _ config: Config) async -> AnalyzerResult {
        // 1. Detect test artifacts
        // 2. Parse coverage reports
        // 3. Return metrics

        let metrics = [
            Metric(
                id: "tests.coverage",
                title: "Test Coverage",
                category: .testing,
                value: .percent(0.85)
            )
        ]

        return AnalyzerResult(metrics: metrics, diagnostics: [])
    }
}
```

Then add normalization in `ScoreEngine.swift`:

```swift
case "tests.coverage":
    return normalizeTestCoverage(metric)
```

---

## Roadmap

### Implemented ✅
- [x] **Git Analysis**: Comprehensive commit quality, branch strategy, frequency tracking
- [x] **Code Analysis**: LOC counting, comment density, file size metrics
- [x] **SwiftLint Integration**: Warnings/errors with graceful degradation
- [x] **Dependency Analysis**: SPM, CocoaPods, Carthage with outdated detection
- [x] **JSON Output**: CI/CD ready with per-metric scores
- [x] **Weighted Scoring**: Configurable weights and thresholds

### Planned
- [ ] **Test Coverage Analysis**: Parse .xcresult bundles for coverage data
- [ ] **Build Performance**: Analyze build times from Xcode logs
- [ ] **Online Outdated Detection**: Git remote tag comparison for dependency freshness
- [ ] **Historical Trends**: Track score over time, show improvement/regression
- [ ] **HTML Reports**: Beautiful web-based reports with charts
- [ ] **Xcode Extension**: Run SwiftHealth directly in Xcode

---

## Contributing

Contributions welcome! Areas of interest:
- New analyzers (test coverage, test analysis, build metrics)
- Enhanced scoring algorithms
- Platform support (Linux, Windows)
- Performance optimizations

## License

MIT License - see LICENSE file for details