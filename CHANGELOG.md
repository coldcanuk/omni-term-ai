# Changelog

## 0.1.0

- POSIX `make install` layout (`PREFIX` / `DESTDIR`)
- Debian `.deb` (`make deb`) and RPM spec (`make rpm`)
- Homebrew formula (`Formula/omni-term-ai.rb`)
- OpenBSD port skeleton under `packaging/openbsd/`
- `omni-secret` backends: secret-tool, macOS Keychain, pass, 0600 files
- Remove hardcoded `/opt/repo` and `/home/chuck` install paths
