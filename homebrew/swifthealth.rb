class Swifthealth < Formula
  desc "CLI tool that analyzes Swift project health and generates actionable reports"
  homepage "https://github.com/nemanjavlahovic/swifthealth"
  url "https://github.com/nemanjavlahovic/swifthealth/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "becb45b7a3e4bfaab7f93a95911f6e6a51187acdb49e18240a86495b020bd15f"
  license "MIT"
  head "https://github.com/nemanjavlahovic/swifthealth.git", branch: "main"

  depends_on xcode: ["16.0", :build]
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/swifthealth"
  end

  test do
    assert_match "swifthealth", shell_output("#{bin}/swifthealth --version")
  end
end
