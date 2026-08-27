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
      Homebrew 6.0+ requires tapping repos to be trusted before their
      formulae may be evaluated. If you tapped this repository, run:

        brew trust coldcanuk/omni-term-ai

      (or the scoped form: brew trust --formula coldcanuk/omni-term-ai/omni-term-ai)

      Store API keys in the macOS Keychain (xai, deepseek, anthropic,
      openai, github, gemini are supported):
        omni-secret store xai
        omni-secret store deepseek

      Pick which AI assistants fill the Command Center panes:
        omni-config

      Launch from a terminal:
        launch-ai-workspace

      Neovim uses NVIM_APPNAME=omni-term-ai and will not replace ~/.config/nvim.
      DeepSeek FIM completion in the Editor uses $DEEPSEEK_API_KEY.
    EOS
  end

  test do
    assert_predicate bin/"launch-ai-workspace", :executable?
    assert_predicate bin/"omni-secret", :executable?
    assert_match(/secret-tool|security|pass|file/, shell_output("#{bin}/omni-secret backend"))
  end
end
