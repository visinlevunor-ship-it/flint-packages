#!/bin/sh
# dmenu, the suckless menu for X: dmenu_run starts programs from it (static).
. "$(dirname "$0")/../common.sh"
ports_init dmenu "${1:?usage: build.sh OUTDIR}"
lib_x11_clients
src=$(unpack "$(fetch universe/s/suckless-tools/suckless-tools_49.orig.tar.xz e1d7f5a734d852f9040486ad14d15fb9cd26ff7ba45461ca57b112d23238667e)")/dmenu
say "dmenu"
cp "$src/config.def.h" "$src/config.h"
(cd "$src" && make -j"$JOBS" dmenu stest CC="$CC" \
    INCS="-I$SYSROOT/include -I$SYSROOT/include/freetype2" \
    LDFLAGS="-static -Wl,--gc-sections -L$SYSROOT/lib $X11_LIBS" \
    CPPFLAGS="-D_DEFAULT_SOURCE -D_BSD_SOURCE -D_XOPEN_SOURCE=700 -D_POSIX_C_SOURCE=200809L -DVERSION=\\\"5.4\\\" -DXINERAMA" \
    >>"$LOG" 2>&1) || die "dmenu build failed"
mkdir -p "$STAGE/usr/bin" "$STAGE/usr/share/licenses/dmenu" "$STAGE/usr/share/man/man1"
cp "$src/dmenu" "$src/stest" "$src/dmenu_path" "$src/dmenu_run" "$STAGE/usr/bin/"
chmod 755 "$STAGE/usr/bin"/*
for m in dmenu stest; do sed "s/VERSION/5.4/g" "$src/$m.1" > "$STAGE/usr/share/man/man1/$m.1"; done
cp "$src/LICENSE" "$STAGE/usr/share/licenses/dmenu/"
ports_package 5.4 "Menu for X: type to pick from a list (dmenu_run starts programs)"
printf 'depends: xorg\n' >> "$OUT/control"
