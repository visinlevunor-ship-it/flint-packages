#!/bin/sh
# st, the suckless terminal for X (static).
#
#   ports/st/build.sh OUTDIR [CONFIG]
#
# Like dwm: CONFIG is a directory under ports/st/configs (default: upstream), each one its own
# package, st or st-N, with `config-of: st` (pkg config install st-1). A config
# directory has config.h (none: upstream's config.def.h), optional *.diff patches applied in
# name order, a description file, an optional depends file and optional files/.
. "$(dirname "$0")/../common.sh"
CONFIG=${2:-upstream}
CDIR="$PORTS/st/configs/$CONFIG"
[ -d "$CDIR" ] || die "no st config $CONFIG (have: $(ls "$PORTS/st/configs" | tr '\n' ' '))"
PKGNAME=st
[ "$CONFIG" = upstream ] || PKGNAME=st-$CONFIG
ports_init "$PKGNAME" "${1:?usage: build.sh OUTDIR [CONFIG]}"
lib_x11_clients
src=$(unpack "$(fetch universe/s/stterm/stterm_0.9.3.orig.tar.xz 507a59102af1cae0fe5276e10467400a02c75e486d9be86972c6de93917e9205)")
say "st ($CONFIG)"
for p in "$CDIR"/*.diff; do
    [ -f "$p" ] || continue
    (cd "$src" && patch -p1 --no-backup-if-mismatch < "$p" >>"$LOG" 2>&1) || die "patch $(basename "$p") failed"
done
if [ -f "$CDIR/config.h" ]; then cp "$CDIR/config.h" "$src/config.h"; else cp "$src/config.def.h" "$src/config.h"; fi
# util: openpty comes from libc
(cd "$src" && make -j"$JOBS" st CC="$CC" \
    STCFLAGS="-I$SYSROOT/include -I$SYSROOT/include/freetype2 -DVERSION=\\\"0.9.3\\\" -D_XOPEN_SOURCE=600 $CFLAGS" \
    STLDFLAGS="-static -Wl,--gc-sections -L$SYSROOT/lib -lm $X11_LIBS" >>"$LOG" 2>&1) || die "st build failed"
mkdir -p "$STAGE/usr/bin" "$STAGE/usr/share/licenses/$PKGNAME" "$STAGE/usr/share/man/man1"
cp "$src/st" "$STAGE/usr/bin/st"
sed "s/VERSION/0.9.3/g" "$src/st.1" > "$STAGE/usr/share/man/man1/st.1"
cp "$src/LICENSE" "$STAGE/usr/share/licenses/$PKGNAME/"
[ -d "$CDIR/files" ] && cp -R "$CDIR/files"/. "$STAGE"/
ports_package 0.9.3 "$(cat "$CDIR/description")"
printf 'config-of: st\n' >> "$OUT/control"
if [ -f "$CDIR/depends" ]; then printf 'depends: %s\n' "$(cat "$CDIR/depends")" >> "$OUT/control"; fi
