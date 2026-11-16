#!/bin/sh
# OpenJDK 21 (the headless runtime), as Ubuntu 24.04 builds it (pinned in ./debs), run by
# flint-glibc. Headless is enough for Minecraft: the game draws with LWJGL and OpenGL, not
# AWT. /usr/bin/java and /usr/bin/keytool point into /usr/lib/jvm.
#
# To move to newer Ubuntu packages: ports/deb-closure.py with the command in ./debs.cmd.
#
#   ports/openjdk-21/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init openjdk-21 "${1:?usage: build.sh OUTDIR}"
GLIBC=1

say "Ubuntu packages"
deb_unpack_list "$PORTS/openjdk-21/debs"
# Debian's alternatives links and java-common leftovers
rm -rf "$STAGE/usr/lib/jvm/.java-1.21.0-openjdk-amd64.jinfo" "$STAGE/etc/.java"
cp -R "$PORTS/openjdk-21/files"/. "$STAGE"/

ports_package 21.0.13-1 "OpenJDK 21 Java runtime from Ubuntu 24.04, for programs built for glibc"
printf 'depends: gtk3-runtime\n' >> "$OUT/control"
ports_split 60000
