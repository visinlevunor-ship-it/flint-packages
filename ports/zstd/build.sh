#!/bin/sh
# zstd: Zstandard compression (static). Usage: ports/zstd/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init zstd "${1:?usage: build.sh OUTDIR}"
src=$(unpack "$(fetch main/libz/libzstd/libzstd_1.5.7+dfsg.orig.tar.xz 0c092ef267edce57ba7f3f2645c861f72eaf5e76273c6c3632869423464b90a5)")
say "zstd"
(cd "$src" && make -j"$JOBS" -C programs zstd CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
    HAVE_ZLIB=0 HAVE_LZMA=0 HAVE_LZ4=0 HAVE_THREAD=1 >>"$LOG" 2>&1)
mkdir -p "$STAGE/usr/bin" "$STAGE/usr/share/licenses/zstd"
cp "$src/programs/zstd" "$STAGE/usr/bin/zstd"
for l in unzstd zstdcat zstdmt; do ln -s zstd "$STAGE/usr/bin/$l"; done
cp "$src/LICENSE" "$src/COPYING" "$STAGE/usr/share/licenses/zstd/"
ports_package 1.5.7 "Zstandard: fast compression (zstd, unzstd, zstdcat)"
