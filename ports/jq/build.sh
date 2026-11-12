#!/bin/sh
# jq, the JSON processor (static, with its bundled Oniguruma). Usage: ports/jq/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init jq "${1:?usage: build.sh OUTDIR}"
src=$(unpack "$(fetch main/j/jq/jq_1.8.2.orig.tar.gz 71b8d6e8f5fe81f6c6d0d110e3892251f6ce76ed095abd315e26e6e1193af3af)")
say "jq"
(cd "$src" && { [ -x configure ] || autoreconf -fi >>"$LOG" 2>&1; } && ./configure $HOSTFLAGS --prefix=/usr --disable-shared --enable-static \
    --enable-all-static --with-oniguruma=builtin --disable-docs --disable-maintainer-mode >>"$LOG" 2>&1 \
    && make -j"$JOBS" >>"$LOG" 2>&1 && mkdir -p "$STAGE/usr/bin" && cp jq "$STAGE/usr/bin/jq")
mkdir -p "$STAGE/usr/share/licenses/jq" && cp "$src/COPYING" "$STAGE/usr/share/licenses/jq/"
ports_package 1.8.2 "Command-line JSON processor"
