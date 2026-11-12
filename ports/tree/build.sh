#!/bin/sh
# tree: list directories as a tree (static). Usage: ports/tree/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init tree "${1:?usage: build.sh OUTDIR}"
src=$(unpack "$(fetch universe/t/tree/tree_2.3.2.orig.tar.gz 6b941dd6cbecfb4d3250700e4d08d8e0c251488981dd4868b90d744234300e21)")
say "tree"
(cd "$src" && make -j"$JOBS" CC="$CC" CFLAGS="$CFLAGS -DLINUX -D_FILE_OFFSET_BITS=64" LDFLAGS="$LDFLAGS" >>"$LOG" 2>&1)
mkdir -p "$STAGE/usr/bin" "$STAGE/usr/share/licenses/tree"
cp "$src/tree" "$STAGE/usr/bin/tree" && cp "$src/LICENSE" "$STAGE/usr/share/licenses/tree/"
ports_package 2.3.2 "List directory contents as a tree"
