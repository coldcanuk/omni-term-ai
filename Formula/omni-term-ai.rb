# frozen_string_literal: true

class OmniTermAi < Formula
  desc "Tmux workspace with Neovim and AI tooling"
  homepage "https://github.com/coldcanuk/omni-term-ai"
  license "GPL-3.0-or-later"
  head "https://github.com/coldcanuk/omni-term-ai.git", branch: "main"

  depends_on "git"
  depends_on "neovim"
  depends_on "ripgrep"
  depends_on "tmux"
  uses_from_macos "unzip"

  def install
    system "make", "install", "PREFIX=#{prefix}"
  end

  def caveats
    <<~EOS
      Store API keys in the macOS Keychain:
        omni-secret store xai
        omni-secret store deepseek

      Launch from a terminal:
        launch-ai-workspace

      Neovim uses NVIM_APPNAME=omni-term-ai and will not replace ~/.config/nvim.
    EOS
  end

  test do
    assert_predicate bin/"launch-ai-workspace", :executable?
    assert_predicate bin/"omni-secret", :executable?
    assert_match(/secret-tool|security|pass|file/, shell_output("#{bin}/omni-secret backend"))
  end
end
