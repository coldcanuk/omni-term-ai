#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/.." && pwd)
VERSION=$(cat "$ROOT/VERSION")
TOP="$ROOT/dist/freebsd"

echo "Preparing FreeBSD port..."
mkdir -p "$TOP/sysutils/omni-term-ai"

cat > "$TOP/sysutils/omni-term-ai/Makefile" <<INNER_EOF
PORTNAME=	omni-term-ai
PORTVERSION=	$VERSION
CATEGORIES=	sysutils editors

MAINTAINER=	Frozen Packet <chuck.pitre@hotmail.com>
COMMENT=	Tmux workspace with Neovim and AI tooling

LICENSE=	GPLv3

RUN_DEPENDS=	neovim>0:editors/neovim \\
		tmux>0:sysutils/tmux \\
		ripgrep>0:textproc/ripgrep \\
		git>0:devel/git

USE_GITHUB=	yes
GH_ACCOUNT=	coldcanuk
GH_TAGNAME=	v\${PORTVERSION}

NO_BUILD=	yes

do-install:
	\${MAKE_CMD} -C \${WRKSRC} install PREFIX=\${PREFIX} DESTDIR=\${STAGEDIR}

.include <bsd.port.mk>
INNER_EOF

cat > "$TOP/sysutils/omni-term-ai/pkg-descr" <<INNER_EOF
Omni Term AI is a tmux workspace with Neovim and AI tooling.
It features a command center that puts AI assistants in shell panes,
and deep editor integrations.

WWW: https://github.com/coldcanuk/omni-term-ai
INNER_EOF

echo "FreeBSD port prepared in $TOP/sysutils/omni-term-ai"
echo "To build on FreeBSD:"
echo "  cp -r $TOP/sysutils/omni-term-ai /usr/ports/sysutils/"
echo "  cd /usr/ports/sysutils/omni-term-ai && make package"
