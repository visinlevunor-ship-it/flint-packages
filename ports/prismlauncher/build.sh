#!/bin/sh
# Prism Launcher (Minecraft), the project's own portable Linux build (Qt 6 bundled), run by
# flint-glibc. Everything lives under /usr/lib/prismlauncher: the launcher, its libraries
# and its Qt; OpenGL comes from mesa-gl and the X libraries from gtk3-runtime, so the
# bundle's copies of glibc, glvnd, Mesa and DRM are dropped. Java comes from openjdk-21.
#
#   ports/prismlauncher/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init prismlauncher "${1:?usage: build.sh OUTDIR}"
GLIBC=1
V=11.1.1

say "fetch"
f=$(fetch "https://github.com/PrismLauncher/PrismLauncher/releases/download/$V/PrismLauncher-Linux-Qt6-Portable-$V.tar.gz" \
    e21949a8101c1803dbc6f67a2cdad48ba80ede1c133f0d1f2a89da07af09e823)
rm -rf "$WORK/x"
mkdir -p "$WORK/x"
tar -xzf "$f" -C "$WORK/x"

say "stage"
D="$STAGE/usr/lib/prismlauncher"
mkdir -p "$D/lib"
cp "$WORK/x/shared/bin/prismlauncher" "$D/prismlauncher"
chmod 755 "$D/prismlauncher"
# the bundle's libraries, except glibc itself (flint-glibc answers those names), the GL
# stack (mesa-gl) and DRM
for l in "$WORK/x/shared/lib"/*; do
    case "$(basename "$l")" in
        ld-linux-*|libc.so*|libm.so*|libpthread.so*|libdl.so*|librt.so*|libresolv.so*|libutil.so*) continue ;;
        libEGL*|libGL*|libOpenGL*|libdrm*|libgbm*|lib.path|gbm|home) continue ;;
    esac
    cp -R "$l" "$D/lib/"
done
# the bundled Qt
Q="$WORK/x/shared/lib/home/runner/work/PrismLauncher/Qt"
QV=$(ls "$Q")
cp -R "$Q/$QV/gcc_64/lib" "$D/qt-lib"
cp -R "$Q/$QV/gcc_64/plugins" "$D/qt-plugins"
# the TIFF plugin wants a libtiff older than gtk3-runtime's; Prism has no TIFF images
rm -f "$D/qt-plugins/imageformats/libqtiff.so"
rm -rf "$D/qt-lib/cmake" "$D/qt-lib"/*.prl "$D/qt-lib"/objects-*
# jars, icons, desktop entry
mkdir -p "$STAGE/usr/share"
cp -R "$WORK/x/share/PrismLauncher" "$STAGE/usr/share/PrismLauncher"
for d in icons applications metainfo mime; do
    [ -d "$WORK/x/share/$d" ] && cp -R "$WORK/x/share/$d" "$STAGE/usr/share/$d"
done
cp -R "$PORTS/prismlauncher/files"/. "$STAGE"/

ports_package $V-1 "Prism Launcher for Minecraft (the project's build, run with flint-glibc)"
printf 'depends: gtk3-runtime, mesa-gl, openjdk-21\n' >> "$OUT/control"
ports_split 60000
