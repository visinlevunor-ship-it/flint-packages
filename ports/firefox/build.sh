#!/bin/sh
# Firefox, as Ubuntu built it for 20.04 (the last Ubuntu release with Firefox as a .deb
# rather than a snap), run by flint-glibc with the libraries from gtk3-runtime.
#
# libxul.so alone is over 50 MB compressed, so the package is split (ports_split):
# firefox-1 holds it and firefox the rest. Build both directories with pkg build.
#
#   ports/firefox/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init firefox "${1:?usage: build.sh OUTDIR}"
GLIBC=1

say "Ubuntu's firefox"
deb_unpack main/f/firefox/firefox_136.0+build3-0ubuntu0.20.04.1_amd64.deb \
    b8d0e0cb0f9aad8f264427400ee12bd9791601df4135a6f257e0449f495a842f
# Ubuntu's crash reporting and AppArmor profiles mean nothing on Flint; the launcher script
# is replaced by ours (files/usr/bin/firefox)
rm -rf "$STAGE/etc/apparmor.d" "$STAGE/etc/apport" "$STAGE/usr/share/apport" "$STAGE/usr/bin/firefox"
cp -R "$PORTS/firefox/files"/. "$STAGE"/

ports_package 136.0-1 "Firefox web browser (Ubuntu's build, run with flint-glibc)" /etc/firefox/syspref.js
printf 'depends: gtk3-runtime\n' >> "$OUT/control"
ports_split 60000
