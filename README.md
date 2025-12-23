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

#### Option 1: Homebrew (Recommended)

```bash
brew install nemanjavlahovic/tap/swifthealth
```

Or tap first, then install:

```bash
brew tap nemanjavlahovic/tap
brew install swifthealth
```

To install the latest development version from `main`:

```bash
brew install --HEAD nemanjavlahovic/tap/swifthealth
```

#### Option 2: Download Pre-built Binary

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

#### Option 3: Build from Source

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

# HTML report with embedded charts
swifthealth analyze --html-out report.html

# Fail if score below threshold
swifthealth analyze --fail-under 80

# Include build analysis (requires Xcode build log)
swifthealth analyze --build-log ~/Library/Developer/Xcode/DerivedData/MyApp-xxx/Logs/Build/*.xcactivitylog

# Include Xcode warnings from xcresult bundle
swifthealth analyze --xcresult ~/path/to/Test.xcresult

# Analyze binary size
swifthealth analyze --app-path ~/path/to/MyApp.app

# Offline mode (skip network calls for dependency checking)
swifthealth analyze --offline

# View health score history and trends
swifthealth history --count 20 --chart
```

---

## Example Output

```
  ███████╗██╗    ██╗██╗███████╗████████╗██╗  ██╗███████╗ █████╗ ██╗  ████████╗██╗  ██╗
  ██╔════╝██║    ██║██║██╔════╝╚══██╔══╝██║  ██║██╔════╝██╔══██╗██║  ╚══██╔══╝██║  ██║
  ███████╗██║ █╗ ██║██║█████╗     ██║   ███████║█████╗  ███████║██║     ██║   ███████║
  ╚════██║██║███╗██║██║██╔══╝     ██║   ██╔══██║██╔══╝  ██╔══██║██║     ██║   ██╔══██║
  ███████║╚███╔███╔╝██║██║        ██║   ██║  ██║███████╗██║  ██║███████╗██║   ██║  ██║
  ╚══════╝ ╚══╝╚══╝ ╚═╝╚═╝        ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝  ╚═╝

  🏥  v0.2.0  •  Project Health Analyzer

  📍 /Users/dev/MyProject
  🔍 git, spm

🔍 Running analyzers...

📊 Git Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Last Commit Recency: 2.50 days
  Active Contributors (30 days): 3 count
  Commit Message Quality: 78.5%
  Conventional Commits: 85.0% percent
  Branch Strategy: trunk-based
  Total Branches: 4 count
  Merge Strategy: rebase-heavy

📝 Code Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Total Code Files: 43 files
  Total Lines of Code: 6857 lines
  Comment Density: 14.1%
  Average File Size: 159 lines/file
  Swift Percentage: 100.0%

📦 Dependency Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SPM Dependencies: 6 count
  SPM Lockfile Age: 5.05 days
  Potentially Outdated Dependencies: 0 count

⏱️ Build Time Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DerivedData Size: 1250.00 MB

📦 Size Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SPM Release Build Size: 12.50 MB
  SPM Debug Build Size: 45.20 MB

╔════════════════════════════════════════════════════════════════════╗
║                          🏥 HEALTH SCORE                           ║
╠════════════════════════════════════════════════════════════════════╣
║                                                                    ║
║    0    10   20   30   40   50   60   70   80   90    100          ║
║    ├────┼────┼────┼────┼────┼────┼────┼────┼────┼────┤             ║
║    ├▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░┤           ║
║    ├─────────────────────────────────────●─────────────┤           ║
║           🔴 Poor         🟠 Fair    🟡 Good    🟢 Excellent       ║
║                                       ▲                            ║
║                                    85/100                          ║
║                                                                    ║
╚════════════════════════════════════════════════════════════════════╝
  ~ +3.2% from last run
```

### JSON Output

```json
{
  "tool": {
    "name": "swifthealth",
    "version": "0.2.0"
  },
  "project": {
    "root": "/Users/dev/MyProject",
    "detected": ["git", "spm"]
  },
  "score": 85,
  "scoreNormalized": 0.85,
  "band": "green",
  "metrics": [
    {
      "id": "git.recency",
      "title": "Last Commit Recency",
      "category": "git",
      "value": {"type": "double", "value": 2.50},
      "unit": "days"
    },
    {
      "id": "build.derivedDataSize",
      "title": "DerivedData Size",
      "category": "build",
      "value": {"type": "double", "value": 1250.00},
      "unit": "MB"
    }
    // ... more metrics
  ],
  "diagnostics": [...],
  "timestamp": "2025-12-23T10:30:00Z"
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
- **Online Outdated Detection**: Fetches latest versions from GitHub with rate limit handling
- **Offline Mode**: Use `--offline` to skip network calls
- **Multi-Manager**: Handles projects using multiple dependency managers

### ⏱️ Build Time Analysis
- **Build Log Parsing**: Analyzes Xcode `.xcactivitylog` files from DerivedData
- **Slow File Detection**: Identifies files that take longest to compile
- **Clean vs Incremental**: Tracks clean and incremental build times
- **Usage**: `swifthealth analyze --build-log /path/to/build.xcactivitylog`

### ⚠️ Xcode Warnings Analysis
- **xcresult Parsing**: Extracts warnings from `.xcresult` bundles
- **Warning Categories**: Groups warnings by type (deprecation, unused, etc.)
- **Actionable Items**: Links warnings to specific files and lines
- **Usage**: `swifthealth analyze --xcresult /path/to/Test.xcresult`

### 📏 Binary Size Analysis
- **App Bundle Analysis**: Analyzes `.app` bundles for size breakdown
- **Framework Detection**: Identifies embedded frameworks and their sizes
- **Asset Catalogs**: Reports asset catalog sizes
- **Usage**: `swifthealth analyze --app-path /path/to/MyApp.app`

### 📈 Historical Trends
- **Automatic Tracking**: Scores are saved to `~/.swifthealth/history/` after each run
- **Trend Visualization**: ASCII charts show score changes over time
- **JSON Export**: Export history for external analysis
- **Usage**: `swifthealth history --count 20 --chart`

### 📄 HTML Reports
- **Beautiful Reports**: Generate self-contained HTML reports with embedded CSS
- **SVG Charts**: Interactive score history visualization
- **Shareable**: Single file, no external dependencies
- **Usage**: `swifthealth analyze --html-out report.html`

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

SwiftHealth includes a comprehensive GitHub Actions workflow example with:
- Automatic health checks on PRs and pushes
- PR comments showing score with emoji indicators
- Artifact storage for historical tracking
- Optional health gate to block PRs that degrade score

**Quick Setup:**

```bash
# Copy the example workflow to your project
cp .github/workflows/health-check.yml.example .github/workflows/health-check.yml
```

Or create your own minimal workflow:

```yaml
name: Health Check
on: [push, pull_request]

jobs:
  health:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for git metrics

      - name: Install SwiftHealth
        run: brew install nemanjavlahovic/tap/swifthealth

      - name: Run Health Check
        run: swifthealth analyze --format json --json-out health.json --fail-under 70

      - name: Upload Report
        uses: actions/upload-artifact@v4
        with:
          name: health-report
          path: health.json
```

**Configuration:**
- Set `HEALTH_THRESHOLD` variable in repository settings (default: 70)
- Uncomment the `health-gate` job in the example to block PRs that drop score by >5 points

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
│   ├── Core/                  # Shared models and utilities
│   │   ├── Models/            # Metric, Config, AnalyzerResult
│   │   ├── Config/            # ConfigLoader with validation
│   │   ├── History/           # HistoryManager, HistoryEntry
│   │   └── Scoring/           # ScoreEngine with normalization
│   ├── Analyzers/             # Analysis implementations
│   │   ├── GitAnalyzer/       # Git metrics via Process API
│   │   ├── CodeAnalyzer/      # LOC counting, file scanning
│   │   ├── BuildAnalyzer/     # Xcode build time analysis
│   │   ├── SizeAnalyzer/      # Binary size analysis
│   │   ├── XcodeAnalyzer/     # Xcode warnings from xcresult
│   │   └── DependencyAnalyzer/ # SPM, CocoaPods, Carthage + online checking
│   └── SwiftHealthCLI/        # CLI entry point
│       ├── Commands/          # analyze, history, init commands
│       ├── Progress/          # Animated progress indicators
│       └── Renderers/         # TTY, JSON, and HTML output
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
- [x] **Build Performance**: Analyze build times from Xcode `.xcactivitylog` files *(v0.2.0)*
- [x] **Online Outdated Detection**: GitHub API integration for real-time version checking *(v0.2.0)*
- [x] **Historical Trends**: Track score over time with ASCII charts *(v0.2.0)*
- [x] **HTML Reports**: Beautiful self-contained reports with SVG charts *(v0.2.0)*
- [x] **Xcode Warnings**: Parse `.xcresult` bundles for warnings analysis *(v0.2.0)*
- [x] **Binary Size Analysis**: Analyze `.app` bundles for size breakdown *(v0.2.0)*

### Planned
- [ ] **Test Coverage Analysis**: Parse .xcresult bundles for coverage data
- [ ] **Xcode Extension**: Run SwiftHealth directly in Xcode
- [ ] **GitHub Action**: Official action for easy CI integration
- [ ] **Baseline Support**: Compare against a baseline score for regressions

---

## Contributing

Contributions welcome! Areas of interest:
- New analyzers (test coverage, test analysis, build metrics)
- Enhanced scoring algorithms
- Platform support (Linux, Windows)
- Performance optimizations

## License

MIT License - see LICENSE file for details