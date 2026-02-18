class Ubo < Formula
  desc "One-command uBlock Origin installer for Google Chrome on macOS"
  homepage "https://github.com/neel49/ubo"
  url "https://github.com/neel49/ubo/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "9709914716058fbca1f7634dfb9139c1d014e4f8a19b4254c053e38be6d2f4af"
  license "MIT"

  depends_on :macos

  def install
    bin.install "bin/ubo"
    (libexec/"lib").install Dir["lib/*"]
    (libexec/"resources").install Dir["resources/*"]

    # Rewrite the base dir resolution so ubo finds lib/ and resources/ in libexec
    inreplace bin/"ubo", /^BASE_DIR=.*$/, "BASE_DIR=\"#{libexec}\""
  end

  def caveats
    <<~EOS
      To set up uBlock Origin in Chrome, run:
        ubo install

      Then open "Chrome uBO" from /Applications or Spotlight.
      Pin it to your Dock for easy access.
    EOS
  end

  test do
    assert_match "ubo", shell_output("#{bin}/ubo version")
  end
end
