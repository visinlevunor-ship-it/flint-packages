#!/bin/sh
# Mesa's OpenGL and Vulkan, as Ubuntu 24.04 builds them (pinned in ./debs), for programs
# built for glibc. One package covers both worlds: llvmpipe draws with the CPU where there
# is no GPU driver (QEMU), and the radeonsi/iris/nouveau drivers and the Vulkan drivers use
# the kernel's DRM devices where there are ones. The X libraries come from gtk3-runtime.
#
# To move to newer Ubuntu packages: ports/deb-closure.py with the command in ./debs.cmd.
#
#   ports/mesa-gl/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init mesa-gl "${1:?usage: build.sh OUTDIR}"
GLIBC=1

say "Ubuntu packages"
deb_unpack_list "$PORTS/mesa-gl/debs"

ports_package 25.2.8-1 "Mesa OpenGL and Vulkan from Ubuntu 24.04, for programs built for glibc"
printf 'depends: gtk3-runtime\n' >> "$OUT/control"
ports_split 60000
