class Swifthealth < Formula
  desc "CLI tool that analyzes Swift project health and generates actionable reports"
  homepage "https://github.com/nemanjavlahovic/swifthealth"
  url "https://github.com/nemanjavlahovic/swifthealth/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "7854c4657238dee6926abbcb971c8f5d1f10689356221609323fca1822587ed3"
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
