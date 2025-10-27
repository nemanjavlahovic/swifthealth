# SwiftHealth Release Process

This document describes how to create releases for SwiftHealth using the automated GitHub Actions pipeline.

## Overview

SwiftHealth uses GitHub Actions to automatically build and publish release binaries when you push a version tag. The pipeline creates:
- **Universal macOS binary** (x86_64 + arm64) - works on all modern Macs
- **Apple Silicon binary** (arm64 only) - native M-series chip performance
- **SHA256 checksums** - for verifying downloads
- **GitHub Release** - with auto-generated release notes and installation instructions

## Creating a Release

### 1. Ensure Everything is Ready

```bash
# Make sure all tests pass
swift test

# Build and verify locally
swift build -c release
.build/release/swifthealth --version

# Ensure main branch is clean
git status
```

### 2. Update Version Number

Update the version in these files:
- `Sources/SwiftHealthCLI/SwiftHealthCLI.swift` (line 9)
- `Sources/SwiftHealthCLI/Renderers/JSONRenderer.swift` (line 19)

```bash
# Example: Update to v0.2.0
# Edit the files, then commit
git add .
git commit -m "Bump version to 0.2.0"
git push origin main
```

### 3. Create and Push Tag

```bash
# Create annotated tag
git tag -a v0.2.0 -m "Release v0.2.0"

# Push tag to trigger release
git push origin v0.2.0
```

### 4. Monitor Release

1. Go to **Actions** tab in GitHub
2. Watch the "Release" workflow run
3. Once complete, check the **Releases** page
4. Verify both binaries are attached and checksums are present

## Manual Release (Optional)

If you need to trigger a release manually:

1. Go to **Actions** → **Release** workflow
2. Click **Run workflow**
3. Enter the tag name (e.g., `v0.2.0`)
4. Click **Run workflow**

## Release Checklist

- [ ] All tests passing locally (`swift test`)
- [ ] Version numbers updated in source files
- [ ] CHANGELOG.md updated (if you have one)
- [ ] Changes committed and pushed to main
- [ ] Tag created and pushed
- [ ] GitHub Actions workflow completed successfully
- [ ] Release appears on GitHub with binaries attached
- [ ] Test download: `curl -L -o swifthealth https://github.com/USER/swifthealth/releases/latest/download/swifthealth-universal`
- [ ] Test binary works: `./swifthealth --version`

## Version Numbering

SwiftHealth follows semantic versioning (semver):

- **Major** (v1.0.0, v2.0.0): Breaking changes
- **Minor** (v0.1.0, v0.2.0): New features, backward compatible
- **Patch** (v0.1.1, v0.1.2): Bug fixes, backward compatible

## Troubleshooting

### Build Fails on GitHub Actions

1. Check the Actions log for specific error
2. Ensure Package.swift dependencies are resolved locally
3. Try building both architectures locally:
   ```bash
   swift build -c release --arch x86_64
   swift build -c release --arch arm64
   ```

### Release Not Created

1. Verify tag format matches `v*` pattern (e.g., `v0.1.0`)
2. Check GitHub Actions permissions (Settings → Actions → General)
3. Ensure `GITHUB_TOKEN` has write permissions

### Binaries Don't Work

1. Check architecture: `file swifthealth-universal`
2. Verify it's executable: `chmod +x swifthealth-universal`
3. Check for code signing issues on macOS

## CI/CD Workflows

### `release.yml`
- **Triggers**: Git tags (`v*`) or manual dispatch
- **Purpose**: Build release binaries and create GitHub Release
- **Runs on**: macOS 14 (Apple Silicon)

### `build-test.yml`
- **Triggers**: Push to main, pull requests
- **Purpose**: Continuous integration testing
- **Runs on**: macOS latest

## Next Steps

Consider adding:
- Homebrew formula for `brew install swifthealth`
- Docker image for Linux support
- Notarization for macOS binaries (removes Gatekeeper warnings)
- Automatic CHANGELOG generation
