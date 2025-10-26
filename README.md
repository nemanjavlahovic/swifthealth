# SwiftHealth

A command-line tool for analyzing the health of Swift/iOS projects and producing a unified health score (0-100).

## Features

- **Git Analysis**: Last commit recency, active contributors
- **Dependency Analysis**: SPM, CocoaPods, Carthage support with outdated dependency detection
- **Code Metrics**: LOC counting, file statistics, code structure analysis
- **Lint Integration**: SwiftLint integration and reporting
- **Test Coverage**: Coverage analysis from `.xcresult` bundles (coming soon)
- **Build Metrics**: Build timing analysis (coming soon)
- **Configurable Scoring**: Customizable weights and thresholds
- **Multiple Output Formats**: TTY (colored terminal), JSON, HTML

## Installation

```bash
git clone https://github.com/yourusername/swifthealth.git
cd swifthealth
swift build -c release
cp .build/release/swifthealth /usr/local/bin/
```

## Usage

### Analyze a project

```bash
# Analyze current directory
swifthealth analyze

# Analyze specific path
swifthealth analyze --path /path/to/project

# Output JSON
swifthealth analyze --format json --json-out report.json

# Offline mode (no network calls)
swifthealth analyze --offline

# Fail if score is below threshold
swifthealth analyze --fail-under 80
```

### Initialize configuration

```bash
swifthealth init
```

Creates a `.swifthealthrc.json` file with default settings.

### Explain a metric

```bash
swifthealth explain git.recency
```

## Configuration

Create a `.swifthealthrc.json` in your project root:

```json
{
  "version": 1,
  "weights": {
    "git.recency": 0.10,
    "git.contributors30d": 0.05,
    "deps.outdated": 0.15,
    "lint.warnings": 0.10,
    "lint.errors": 0.10,
    "code.loc": 0.05,
    "code.structure": 0.05,
    "test.coverage": 0.20,
    "build.avgTime": 0.20
  },
  "thresholds": {
    "git.recency.days.warn": 7,
    "git.recency.days.fail": 30,
    "deps.outdated.warnPct": 0.10,
    "deps.outdated.failPct": 0.30,
    "lint.warnings.warn": 50,
    "lint.warnings.fail": 200,
    "lint.errors.warn": 1,
    "lint.errors.fail": 10,
    "test.coverage.warn": 0.70,
    "test.coverage.fail": 0.50,
    "build.avgTime.warnSec": 45,
    "build.avgTime.failSec": 120
  },
  "ci": {
    "failUnder": 80
  },
  "plugins": []
}
```

## Requirements

- macOS 13.0+
- Swift 5.9+
- Xcode command line tools

## Development Status

**Current Version: 0.1.0-alpha**

- [x] Core models and configuration
- [ ] CLI interface (in progress)
- [ ] Git analyzer
- [ ] Dependency analyzer
- [ ] Code analyzer
- [ ] SwiftLint analyzer
- [ ] Scoring engine
- [ ] TTY renderer
- [ ] JSON renderer

## License

MIT

## Contributing

Contributions welcome! Please open an issue or PR.
