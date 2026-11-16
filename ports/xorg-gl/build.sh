#!/bin/sh
# The X.Org server as Ubuntu 24.04 builds it (pinned in ./debs), run by flint-glibc, for
# OpenGL: unlike Flint's static Xorg, this server can load Mesa's drivers, so it offers GLX
# (drawn by llvmpipe without a GPU driver) and, with a DRM device, glamor and DRI3 with
# hardware acceleration. startx (xorg 21.1.26.1 and later) uses it when it is installed.
# The input driver is the libinput module; the configuration startx writes works unchanged.
#
# To move to newer Ubuntu packages: ports/deb-closure.py with the command in ./debs.cmd.
#
#   ports/xorg-gl/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init xorg-gl "${1:?usage: build.sh OUTDIR}"
GLIBC=1

say "Ubuntu packages"
deb_unpack_list "$PORTS/xorg-gl/debs"
# Debian plumbing the server does not need on Flint
rm -rf "$STAGE/etc/init.d" "$STAGE/etc/X11/Xsession.d" "$STAGE/usr/share/initramfs-tools" \
    "$STAGE/etc/udev" "$STAGE/usr/lib/udev"
# Debian's X wrapper scripts collide with the static xorg package; the server itself is
# /usr/lib/xorg/Xorg, which startx calls by that path
rm -f "$STAGE/usr/bin/X" "$STAGE/usr/bin/Xorg" "$STAGE/usr/bin/gtf"
# the static xorg package ships these already
rm -f "$STAGE/usr/share/X11/xorg.conf.d/10-quirks.conf"
rm -rf "$STAGE/usr/share/libinput"
rmdir -p "$STAGE/usr/share/X11/xorg.conf.d" 2>/dev/null || true

ports_package 21.1.12-1 "X.Org server from Ubuntu 24.04 (run with flint-glibc): GLX, glamor, DRI3 for mesa-gl"
printf 'depends: xorg, mesa-gl\n' >> "$OUT/control"
ports_split 60000
