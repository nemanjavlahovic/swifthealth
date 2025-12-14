# Homebrew Distribution for SwiftHealth

## For Users

### Install SwiftHealth

```bash
brew install nemanjavlahovic/tap/swifthealth
```

Or:

```bash
brew tap nemanjavlahovic/tap
brew install swifthealth
```

### Install from HEAD (latest main branch)

```bash
brew install --HEAD nemanjavlahovic/tap/swifthealth
```

---

## For Maintainers (Setup Instructions)

### Step 1: Create the Tap Repository

1. Go to GitHub and create a new **public** repository named `homebrew-tap`
   - URL will be: `https://github.com/nemanjavlahovic/homebrew-tap`

2. Clone it locally:
   ```bash
   git clone https://github.com/nemanjavlahovic/homebrew-tap.git
   cd homebrew-tap
   ```

3. Create the Formula directory and copy the formula:
   ```bash
   mkdir -p Formula
   cp /path/to/swifthealth/homebrew/swifthealth.rb Formula/
   ```

4. Commit and push:
   ```bash
   git add .
   git commit -m "Add swifthealth formula"
   git push
   ```

### Step 2: Create a Release (to get SHA256)

1. Tag and push a release on the main swifthealth repo:
   ```bash
   cd /path/to/swifthealth
   git tag -a v0.1.0 -m "Release v0.1.0"
   git push origin v0.1.0
   ```

2. Wait for the release workflow to complete (creates binaries)

3. Get the SHA256 of the source tarball:
   ```bash
   curl -sL https://github.com/nemanjavlahovic/swifthealth/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
   ```

4. Update the formula with the real SHA256:
   ```bash
   cd /path/to/homebrew-tap
   # Edit Formula/swifthealth.rb and replace PLACEHOLDER_SHA256
   git commit -am "Update SHA256 for v0.1.0"
   git push
   ```

### Step 3: Test the Installation

```bash
# Remove any existing installation
brew uninstall swifthealth 2>/dev/null

# Install from your tap
brew install nemanjavlahovic/tap/swifthealth

# Verify
swifthealth --version
swifthealth analyze .
```

---

## Updating the Formula for New Releases

When you release a new version (e.g., v0.2.0):

1. Update the `url` in the formula to point to the new tag
2. Get the new SHA256: `curl -sL https://github.com/nemanjavlahovic/swifthealth/archive/refs/tags/v0.2.0.tar.gz | shasum -a 256`
3. Update the `sha256` in the formula
4. Commit and push to homebrew-tap

Or use the automated GitHub Action (see `.github/workflows/update-homebrew.yml` in main repo).

---

## Troubleshooting

### "SHA256 mismatch"
The tarball changed or you have the wrong hash. Re-download and recalculate.

### "No bottle available"
This is normal for taps. Homebrew builds from source.

### Build fails
Ensure Xcode 15+ is installed: `xcode-select --install`
