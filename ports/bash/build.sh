#!/bin/sh
# GNU bash (static). Usage: ports/bash/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init bash "${1:?usage: build.sh OUTDIR}"
lib_ncurses
src=$(unpack "$(fetch main/b/bash/bash_5.3.orig.tar.xz a70de6bb41f5e192534a5a1836b1d7fad9a8d4818a6e1506d70f38441552c17a)")
say "bash"
(cd "$src" && ./configure $HOSTFLAGS --prefix=/usr --bindir=/bin --without-bash-malloc --enable-static-link \
    --disable-nls --with-curses --enable-readline >>"$LOG" 2>&1 \
    && make -j"$JOBS" >>"$LOG" 2>&1 && mkdir -p "$STAGE/bin" && cp bash "$STAGE/bin/bash")
mkdir -p "$STAGE/usr/share/licenses/bash" && cp "$src/COPYING" "$STAGE/usr/share/licenses/bash/"
ports_package 5.3 "GNU Bourne-Again shell"
