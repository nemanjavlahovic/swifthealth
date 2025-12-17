class Swifthealth < Formula
  desc "CLI tool that analyzes Swift project health and generates actionable reports"
  homepage "https://github.com/nemanjavlahovic/swifthealth"
  url "https://github.com/nemanjavlahovic/swifthealth/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "5c069680e778c649a58814f2ab158651db23b3c94396caf561ba99087d9bb60b"
  license "MIT"
  head "https://github.com/nemanjavlahovic/swifthealth.git", branch: "main"

  depends_on xcode: ["15.0", :build]
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/swifthealth"
  end

  test do
    assert_match "swifthealth", shell_output("#{bin}/swifthealth --version")
  end
end
