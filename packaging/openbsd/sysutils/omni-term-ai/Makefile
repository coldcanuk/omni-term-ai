COMMENT =	tmux workspace with Neovim and AI tooling

V =		0.1.0
DISTNAME =	omni-term-ai-${V}
CATEGORIES =	sysutils editors

HOMEPAGE =	https://github.com/coldcanuk/omni-term-ai
MAINTAINER =	Frozen Packet <chuck.pitre@hotmail.com>

# GPLv3+
PERMIT_PACKAGE =	Yes

GH_ACCOUNT =	coldcanuk
GH_PROJECT =	omni-term-ai
# Replace with GH_COMMIT until a v${V} GitHub tag exists.
GH_TAGNAME =	v${V}

RUN_DEPENDS =	editors/neovim devel/git textproc/ripgrep

NO_BUILD =	Yes
NO_TEST =	Yes
PKG_ARCH =	*

do-install:
	${MAKE_PROGRAM} -C ${WRKSRC} install PREFIX=${PREFIX} DESTDIR=${DESTDIR}

.include <bsd.port.mk>
