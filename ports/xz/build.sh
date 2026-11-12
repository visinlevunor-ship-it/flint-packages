#!/bin/sh
# XZ Utils (static). Usage: ports/xz/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init xz "${1:?usage: build.sh OUTDIR}"
src=$(unpack "$(fetch main/x/xz-utils/xz-utils_5.8.4.orig.tar.xz 4ce24038fd4221e0d13bc1a2de7a4db56e90b92b3bf75321f6c14be73f65de4b)")
say "xz"
(cd "$src" && ./configure $HOSTFLAGS --prefix=/usr --disable-shared --disable-nls --disable-doc --disable-scripts \
    --disable-lzmadec --disable-lzmainfo >>"$LOG" 2>&1 && make -j"$JOBS" >>"$LOG" 2>&1 && make install DESTDIR="$STAGE" >>"$LOG" 2>&1)
rm -rf "$STAGE/usr/include" "$STAGE/usr/lib" "$STAGE/usr/share/man" "$STAGE/usr/share/doc"
mkdir -p "$STAGE/usr/share/licenses/xz" && cp "$src/COPYING" "$STAGE/usr/share/licenses/xz/"
ports_package 5.8.4 "XZ / LZMA compression (xz, unxz, xzcat)"
