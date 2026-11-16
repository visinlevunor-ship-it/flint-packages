#!/bin/sh
# dwm, the suckless tiling window manager for X (static).
#
#   ports/dwm/build.sh OUTDIR [CONFIG]
#
# CONFIG is a directory under ports/dwm/configs (default: upstream, dwm as suckless ships it);
# the others are numbered. Each one is its own package, dwm or dwm-N, with `config-of: dwm`:
# install or switch with `pkg config install dwm-N`. A config directory has config.h, optional *.diff
# patches applied in name order, a description file, an optional depends file (packages it needs), optional extra files under files/,
# and optional programs/*.c, each built into /usr/bin.
. "$(dirname "$0")/../common.sh"
CONFIG=${2:-upstream}
CDIR="$PORTS/dwm/configs/$CONFIG"
[ -d "$CDIR" ] || die "no dwm config $CONFIG (have: $(ls "$PORTS/dwm/configs" | tr '\n' ' '))"
PKGNAME=dwm
[ "$CONFIG" = upstream ] || PKGNAME=dwm-$CONFIG
ports_init "$PKGNAME" "${1:?usage: build.sh OUTDIR [CONFIG]}"
lib_x11_clients
src=$(unpack "$(fetch universe/d/dwm/dwm_6.8.orig.tar.gz bcf540589ad174d4073f4efa658828411e2f5ba63196cfaf6b71363700f590b7)")
say "dwm ($CONFIG)"
for p in "$CDIR"/*.diff; do
    [ -f "$p" ] || continue
    (cd "$src" && patch -p1 --no-backup-if-mismatch < "$p" >>"$LOG" 2>&1) || die "patch $(basename "$p") failed"
done
if [ -f "$CDIR/config.h" ]; then cp "$CDIR/config.h" "$src/config.h"; else cp "$src/config.def.h" "$src/config.h"; fi
(cd "$src" && make -j"$JOBS" CC="$CC" \
    INCS="-I$SYSROOT/include -I$SYSROOT/include/freetype2" \
    LIBS="-L$SYSROOT/lib $X11_LIBS" LDFLAGS="-static -Wl,--gc-sections -L$SYSROOT/lib $X11_LIBS" \
    CPPFLAGS="-D_DEFAULT_SOURCE -D_BSD_SOURCE -D_XOPEN_SOURCE=700L -DVERSION=\\\"6.8\\\" -DXINERAMA" >>"$LOG" 2>&1) || die "dwm build failed"
mkdir -p "$STAGE/usr/bin" "$STAGE/usr/share/licenses/$PKGNAME" "$STAGE/usr/share/man/man1"
cp "$src/dwm" "$STAGE/usr/bin/dwm"
cp "$src/LICENSE" "$STAGE/usr/share/licenses/$PKGNAME/"
# small programs that come with the configuration (dwm-1's status bar)
for c in "$CDIR"/programs/*.c; do
    [ -f "$c" ] || continue
    $CC $CFLAGS -I"$SYSROOT/include" -o "$STAGE/usr/bin/$(basename "$c" .c)" "$c"         -static -Wl,--gc-sections -L"$SYSROOT/lib" $X11_LIBS >>"$LOG" 2>&1 || die "$(basename "$c") failed"
done
[ -d "$CDIR/files" ] && cp -R "$CDIR/files"/. "$STAGE"/
ports_package 6.8 "$(cat "$CDIR/description")"
printf 'config-of: dwm\n' >> "$OUT/control"
if [ -f "$CDIR/depends" ]; then printf 'depends: %s\n' "$(cat "$CDIR/depends")" >> "$OUT/control"; fi
