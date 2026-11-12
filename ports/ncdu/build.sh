#!/bin/sh
# ncdu: disk usage browser (static). Usage: ports/ncdu/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init ncdu "${1:?usage: build.sh OUTDIR}"
lib_ncurses
src=$(unpack "$(fetch universe/n/ncdu/ncdu_1.22.orig.tar.gz 8af3431c09769f2a6e75f2260707d51792f9043db49ca6c3f940adfdc12fe063)")
say "ncdu"
(cd "$src" && ./configure $HOSTFLAGS --prefix=/usr --with-ncursesw CPPFLAGS="$CPPFLAGS -I$SYSROOT/include/ncursesw" >>"$LOG" 2>&1 \
    && make -j"$JOBS" >>"$LOG" 2>&1 && mkdir -p "$STAGE/usr/bin" && cp ncdu "$STAGE/usr/bin/ncdu")
mkdir -p "$STAGE/usr/share/licenses/ncdu" && cp "$src/COPYING" "$STAGE/usr/share/licenses/ncdu/"
ports_package 1.22 "Disk usage browser for the terminal"
