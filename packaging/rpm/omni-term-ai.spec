Name:           omni-term-ai
Version:        @VERSION@
Release:        1%{?dist}
Summary:        Tmux workspace with Neovim and AI tooling
License:        GPLv3+
URL:            https://github.com/coldcanuk/omni-term-ai
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
BuildRequires:  make
Requires:       tmux
Requires:       neovim
Requires:       git
Requires:       gcc
Requires:       make
Requires:       ripgrep
Requires:       unzip
Requires:       libsecret

%description
Omni Term AI is a tmux-based dual-tab workspace that launches a command
center with configurable AI assistant panes (grok, agy, copilot, claude,
codex, deepseek) and a Neovim editor with DeepSeek Fill-In-The-Middle
completion. API keys are read from the OS keychain via omni-secret
(libsecret on Linux).

%prep
%setup -q

%build
# Architecture-independent scripts; nothing to compile.

%install
make DESTDIR=%{buildroot} PREFIX=/usr install

%files
/usr/bin/launch-ai-workspace
/usr/bin/omni-exec
/usr/bin/omni-secret
/usr/bin/omni-config
/usr/bin/tmux-toggle-scratch
/usr/share/omni-term-ai
/usr/share/applications/ai-workspace.desktop
/usr/share/icons/hicolor/scalable/apps/ai-workspace.svg
%{_mandir}/man1/launch-ai-workspace.1*
/usr/share/doc/omni-term-ai

%changelog
* Thu Aug 27 2026 Frozen Packet <chuck.pitre@hotmail.com> - @VERSION@-1
- Initial RPM packaging.
