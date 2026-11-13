#!/bin/sh
# GTK 3 and the libraries it needs, as Ubuntu 24.04 builds them (pinned in ./debs), for
# programs built for glibc: Flint runs them with flint-glibc, which comes with Flint 1.1.
# The libraries go to /usr/lib/x86_64-linux-gnu, a directory Flint's own programs don't use.
#
# Left out because Flint's xorg package already has them: fontconfig's configuration and
# tools, the X11 locale data and the keyboard layouts. Also left out: dconf (it needs a D-Bus
# session; programs keep settings in a key file instead, see GSETTINGS_BACKEND).
#
# Needs glib-compile-schemas on the build host (Ubuntu: libglib2.0-bin) for the settings
# schemas; gtk-update-icon-cache is used too if present.
#
# To move to newer Ubuntu packages: ports/deb-closure.py with the command in ./debs.cmd.
#
#   ports/gtk3-runtime/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init gtk3-runtime "${1:?usage: build.sh OUTDIR}"
GLIBC=1
command -v glib-compile-schemas >/dev/null || die "needs glib-compile-schemas (Ubuntu: apt install libglib2.0-bin)"

say "Ubuntu packages"
deb_unpack_list "$PORTS/gtk3-runtime/debs"

say "caches"
glib-compile-schemas "$STAGE/usr/share/glib-2.0/schemas" || die "glib-compile-schemas failed"
if command -v gtk-update-icon-cache >/dev/null; then
    for t in "$STAGE"/usr/share/icons/*/; do
        [ -f "$t/index.theme" ] && gtk-update-icon-cache -q -f -t "$t" >>"$LOG" 2>&1 || true
    done
fi
# helpers for Debian's package scripts, not programs Flint runs
rm -rf "$STAGE/usr/share/gtk-3.0/settings.ini.dpkg" "$STAGE/etc/gtk-3.0/im-multipress.conf.dpkg"

ports_package 3.24.41-1 "GTK 3 and its libraries from Ubuntu 24.04, for programs built for glibc"
printf 'depends: xorg\n' >> "$OUT/control"
