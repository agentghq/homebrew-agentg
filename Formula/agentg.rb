# Starter Homebrew formula for AGENTG (Agent.G).
#
# The CLI builds from tagged source. macOS capture ships as the matching
# Developer ID signed and notarized companion, pinned separately below.
#
# To use as a tap:
#   1. Create a repo named `homebrew-agentg` under agentghq and drop this file at Formula/agentg.rb
#   2. brew tap agentghq/agentg && brew install agentg
#
# To try locally without a tap:
#   brew install --build-from-source ./HomebrewFormula/agentg.rb
#
# Maintainer: on each release, bump `url` to the new tag and update `sha256`
# (run `brew fetch --build-from-source ./HomebrewFormula/agentg.rb` or
# `shasum -a 256` on the source tarball).
class Agentg < Formula
  desc "Local egress firewall for AI agents: observe, gate, approve, audit"
  homepage "https://app.agentg.dev"
  # The GitHub repo is private, so source archives are served through the
  # site's authenticated download proxy. Bytes are identical to the GitHub
  # tarball API response; sha256 is pinned and verified by Homebrew.
  url "https://app.agentg.dev/download/v0.4.2/source.tar.gz"
  sha256 "e3da5020f6256c2814a5040ec811dd78f6df545b0ff9328e3a9c07cae56da4ae"
  license "PolyForm-Noncommercial-1.0.0"
  head "https://github.com/agentghq/AgentG-Dev.git", branch: "main"

  depends_on "go" => :build

  on_macos do
    depends_on macos: :sequoia
    resource "native-capture" do
      url "https://app.agentg.dev/download/v0.4.2/AgentGCapture.zip"
      sha256 "2af26fb18e6179ae59808100a65384c38811f3879fe45ef43671ce1f09e10ecf"
    end
  end

  skip_clean "libexec/AgentGCapture.app"

  def install
    # The Go module is the repo root. The license public keys are embedded from
    # internal/license/keys/ via go:embed, so source builds verify licenses the
    # same as release binaries.
    ldflags = %W[
      -s -w
      -X main.version=#{version}
      -X main.commit=brew
      -X main.date=#{time.iso8601}
    ]
    system "go", "build", *std_go_args(ldflags: ldflags.join(" ")), "./cmd/agentg"
    if OS.mac?
      resource("native-capture").stage do
        libexec.install Pathname.pwd
      end
    end
  end

  def caveats
    <<~EOS
      Finish installation and approve the macOS network extension prompts:
        #{bin}/agentg setup
      To upgrade an existing runtime, first run agentg off, then the setup command above.
    EOS
  end

  test do
    ENV["AGENTG_STATE"] = (testpath/"state.db").to_s
    # Version metadata works without any state DB or privileged setup.
    assert_match version.to_s, shell_output("#{bin}/agentg version --short")
    assert_match "guard", shell_output("#{bin}/agentg help")

    # Unknown commands must fail loudly (exit 1), not silently print help.
    output = shell_output("#{bin}/agentg definitely-not-a-command 2>&1", 1)
    assert_match "unknown command", output
    if OS.mac?
      system "/usr/bin/codesign", "--verify", "--deep", "--strict", "#{libexec}/AgentGCapture.app"
      assert_equal version.to_s, JSON.parse((libexec/"AgentGCapture.app/Contents/Resources/agentg-release.json").read)["version"]
    end
  end
end
