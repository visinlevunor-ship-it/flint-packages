#!/bin/sh
# strace: trace system calls (static). Usage: ports/strace/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init strace "${1:?usage: build.sh OUTDIR}"
src=$(unpack "$(fetch main/s/strace/strace_7.2+ds.orig.tar.xz a8bcd623eacfa11959b696be5bc54eecd88992470301c936a629dd682acf2beb)")
say "strace"
# configure also writes the packaging files the source package leaves out
for f in debian/changelog.in strace.spec.in; do mkdir -p "$(dirname "$src/$f")"; [ -f "$src/$f" ] || : > "$src/$f"; done
(cd "$src" && ./configure $HOSTFLAGS --prefix=/usr --enable-mpers=no --disable-gcc-Werror --without-libunwind --without-libdw \
    --without-libselinux >>"$LOG" 2>&1 && make -j"$JOBS" >>"$LOG" 2>&1 && mkdir -p "$STAGE/usr/bin" && cp src/strace "$STAGE/usr/bin/strace")
mkdir -p "$STAGE/usr/share/licenses/strace" && cp "$src/COPYING" "$STAGE/usr/share/licenses/strace/"
ports_package 7.2 "Trace the system calls and signals of a program"
