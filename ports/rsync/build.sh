#!/bin/sh
# rsync: fast incremental file transfer (static). Usage: ports/rsync/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init rsync "${1:?usage: build.sh OUTDIR}"
lib_zlib
lib_popt
src=$(unpack "$(fetch main/r/rsync/rsync_3.5.2+ds1.orig.tar.xz a2cc02b428f109d15b0b60d859ae74e2dcbabd23254296df5399714f74cbbdff)")
say "rsync"
# Debian's source package drops the bundled zlib and popt (built above); configure still names them
for d in zlib popt; do mkdir -p "$src/$d"; [ -f "$src/$d/dummy.in" ] || : > "$src/$d/dummy.in"; done
(cd "$src" && ./configure $HOSTFLAGS --prefix=/usr --disable-openssl --disable-xxhash --disable-zstd --disable-lz4 \
    --disable-md2man --disable-idn --disable-locale --disable-iconv --without-included-zlib --without-included-popt >>"$LOG" 2>&1 \
    && make -j"$JOBS" >>"$LOG" 2>&1 && mkdir -p "$STAGE/usr/bin" && cp rsync "$STAGE/usr/bin/rsync")
mkdir -p "$STAGE/usr/share/licenses/rsync" && cp "$src/COPYING" "$STAGE/usr/share/licenses/rsync/"
ports_package 3.5.2 "Fast, incremental file copying, locally and over ssh"
