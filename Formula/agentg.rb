# Starter Homebrew formula for AGENTG (Agent.G).
#
# Build-from-source on purpose: a binary compiled locally by Homebrew is never
# quarantined, so Gatekeeper never blocks it — which is how we ship a clean macOS
# install without an Apple Developer ID / notarization. It also means users run
# bytes they can rebuild from the tagged source.
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
  url "https://app.agentg.dev/download/v0.3.3/source.tar.gz"
  sha256 "5eb09809b3f0047b2ef4cc993a9a97c77af784375cdef0f9b2593409331594fa"
  license "PolyForm-Noncommercial-1.0.0"
  head "https://github.com/agentghq/AgentG-Dev.git", branch: "main"

  depends_on "go" => :build

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
  end

  test do
    # Version metadata works without any state DB or privileged setup.
    assert_match version.to_s, shell_output("#{bin}/agentg version --short")
    assert_match "guard", shell_output("#{bin}/agentg help")

    # Unknown commands must fail loudly (exit 1), not silently print help.
    output = shell_output("#{bin}/agentg definitely-not-a-command 2>&1", 1)
    assert_match "unknown command", output
  end
end
