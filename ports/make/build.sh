#!/bin/sh
# GNU make (static). Usage: ports/make/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init make "${1:?usage: build.sh OUTDIR}"
src=$(unpack "$(fetch main/m/make-dfsg/make-dfsg_4.4.1.orig.tar.xz 3b16b00ea1079af9f8096bbc71ff7cc00c249fc6a862003da3c42308a0adb0fe)")
say "make"
# Debian's source package leaves out the manual; give configure an empty doc/Makefile.
mkdir -p "$src/doc" && [ -f "$src/doc/Makefile.in" ] || printf 'all:\ninstall:\nclean:\ndistclean:\ncheck:\n.PHONY: all install clean distclean check\n' > "$src/doc/Makefile.in"
: > "$src/doc/make.1"
(cd "$src" && { [ -x configure ] || autoreconf -fi >>"$LOG" 2>&1; } && ./configure $HOSTFLAGS --prefix=/usr --disable-nls --without-guile >>"$LOG" 2>&1 \
    && make -j"$JOBS" >>"$LOG" 2>&1 && mkdir -p "$STAGE/usr/bin" && cp make "$STAGE/usr/bin/make")
mkdir -p "$STAGE/usr/share/licenses/make" && cp "$src/COPYING" "$STAGE/usr/share/licenses/make/"
ports_package 4.4.1 "GNU make: build automation"
