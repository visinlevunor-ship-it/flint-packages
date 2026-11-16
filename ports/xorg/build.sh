#!/bin/sh
# The X.Org X server (Xorg), static, with its drivers built in: modesetting (any GPU with a
# kernel modesetting driver: AMD, Intel, NVIDIA's nouveau, virtual GPUs) and libinput
# (keyboards, mice, touchpads). Xorg normally loads drivers as shared objects; here they are
# linked into the server and its module loader hands them out from a table. Rendering is
# done by the CPU (no OpenGL acceleration: that needs Mesa).
#
# Also: xkbcomp and setxkbmap, the keyboard layouts (xkeyboard-config), and startx.
#
#   ports/xorg/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init xorg "${1:?usage: build.sh OUTDIR}"
lib_x11_clients
meson_cross

say "server libraries"
meson_lib "$(unpack "$(fetch main/p/pixman/pixman_0.46.4.orig.tar.gz d09c44ebc3bd5bee7021c79f922fe8fb2fb57f7320f55e97ff9914d2346a591c)")" \
    -Dtests=disabled -Ddemos=disabled -Dgtk=disabled -Dlibpng=disabled
ac_lib "$(unpack "$(fetch main/libf/libfontenc/libfontenc_1.1.8.orig.tar.gz b55039f70959a1b2f02f4ec8db071e5170528d2c9180b30575dccf7510d7fb9f)")"
ac_lib "$(unpack "$(fetch main/libx/libxfont/libxfont_2.0.9.orig.tar.gz 8564b4df365bc5a6cb0c15900dc688f6e8f47b00a8571c6708c916dfb85066ba)")" \
    --disable-devel-docs --without-xmlto --without-fop --disable-ipv6
ac_lib "$(unpack "$(fetch main/libx/libxkbfile/libxkbfile_1.1.0.orig.tar.gz 2a92adda3992aa7cbad758ef0b8dfeaedebb49338b772c64ddf369d78c1c51d3)")"
ac_lib "$(unpack "$(fetch main/libm/libmd/libmd_1.3.0.orig.tar.xz fc0f1eb6b6766470326f2c014693809190e67dba84274a6fbae9d4912d066706)")"
meson_lib "$(unpack "$(fetch main/libd/libdrm/libdrm_2.4.134.orig.tar.xz ac5e74d157830eb8bee44c6a6bf3ad49774ef0dd2a72bdad74a8f20308b52a95)")" \
    -Dintel=disabled -Dradeon=disabled -Damdgpu=disabled -Dnouveau=disabled -Dvmwgfx=disabled \
    -Domap=disabled -Dexynos=disabled -Dfreedreno=disabled -Dtegra=disabled -Dvc4=disabled \
    -Detnaviv=disabled -Dcairo-tests=disabled -Dman-pages=disabled -Dvalgrind=disabled -Dtests=false
xcvt=$(unpack "$(fetch main/libx/libxcvt/libxcvt_0.1.3.orig.tar.xz a929998a8767de7dfa36d6da4751cdbeef34ed630714f2f4a767b351f2442e01)")
sed -i 's/shared_library(/library(/' "$xcvt/lib/meson.build"   # it asks for a shared library by name
meson_lib "$xcvt"
meson_lib "$(unpack "$(fetch main/libp/libpciaccess/libpciaccess_0.19.orig.tar.xz 3c55aa86c82e54a4e3109786f0463530d53b36b6d1cfd14616454f985dd2aa43)")" \
    -Dzlib=disabled
ac_lib "$(unpack "$(fetch main/m/mtdev/mtdev_1.1.7.orig.tar.gz a55bd02a9af4dd266c0042ec608744fff3a017577614c057da09f1f4566ea32c)")"
meson_lib "$(unpack "$(fetch main/libe/libevdev/libevdev_1.14.0+dfsg.orig.tar.xz 11d8e2050a90fe3db9f6bf4d4d8582d147c6bde3b1e696cd4b81f13b563793a4)")" \
    -Dtests=disabled -Ddocumentation=disabled
# libudev without udev: device properties (keyboard? touchpad?) worked out from sysfs
udz="$WORK/src/libudev-zero"
git_clone illiliti/libudev-zero 1.0.5 7a6eee2db11f2eb0f7fd065ae9597fcd270e6734 "$udz"
(cd "$udz" && make -j"$JOBS" CC="$CC" AR="$AR" CFLAGS="$CFLAGS" libudev.a >>"$LOG" 2>&1 \
    && make PREFIX="$SYSROOT" install-static install-headers install-pkgconfig >>"$LOG" 2>&1) || die "libudev-zero failed"
li=$(unpack "$(fetch main/libi/libinput/libinput_1.31.3.orig.tar.gz 1c37348cf34cc1ac85c94f41a978ec6a81613f7146bf994c9457137c4a85a249)")
sed -i "s/^lib_libinput = shared_library('input',/lib_libinput = library('input',/" "$li/meson.build"
# the device quirks are read at run time from /usr/share/libinput (shipped below)
sed -i "s|^config_h.set_quoted('LIBINPUT_QUIRKS_DIR', dir_data)|config_h.set_quoted('LIBINPUT_QUIRKS_DIR', '/usr/share/libinput')|; \
        s|^config_h.set_quoted('LIBINPUT_QUIRKS_OVERRIDE_FILE', libinput_data_override_path)|config_h.set_quoted('LIBINPUT_QUIRKS_OVERRIDE_FILE', '/etc/libinput/local-overrides.quirks')|" "$li/meson.build"
grep -q "'/usr/share/libinput'" "$li/meson.build" || die "libinput: quirks path not found in meson.build"
meson_lib "$li" \
    -Dlibwacom=false -Ddebug-gui=false -Dtests=false -Ddocumentation=false -Dinstall-tests=false \
    -Dzshcompletiondir=no -Dudev-dir="$SYSROOT/lib/udev" -Dmtdev=true

say "xkbcomp, setxkbmap"
ac_lib "$(unpack "$(fetch main/libx/libxrandr/libxrandr_1.5.4.orig.tar.gz c72c94dc3373512ceb67f578952c5d10915b38cc9ebb0fd176a49857b8048e22)")"   # for setxkbmap
xku=$(unpack "$(fetch main/x/x11-xkb-utils/x11-xkb-utils_7.7+9build1.tar.xz 2f7fee7b72120f32dcad6bf8f49d00994d064cdbe5aaffc93920356a3c84cdd8)")
for t in xkbcomp setxkbmap; do
    (cd "$xku/$t" && { [ -x configure ] || autoreconf -fi >>"$LOG" 2>&1; } \
        && ./configure $HOSTFLAGS --prefix=/usr --with-xkb-config-root=/usr/share/X11/xkb >>"$LOG" 2>&1 \
        && make -j"$JOBS" LIBS="-lxkbfile -lXrandr $X11_LIBS" >>"$LOG" 2>&1 && make install DESTDIR="$STAGE" >>"$LOG" 2>&1) || die "$t failed"
done

say "keyboard layouts"
xkc=$(unpack "$(fetch main/x/xkeyboard-config/xkeyboard-config_2.48.orig.tar.xz b77041324f0109f77161ee43743fe04baa485866af8460d31e476ad3f7648fd5)")
(cd "$xkc" && meson setup _b --prefix=/usr -Dxorg-rules-symlinks=true -Dcompat-rules=true -Dnls=false >>"$LOG" 2>&1 \
    && ninja -C _b >>"$LOG" 2>&1 && DESTDIR="$STAGE" ninja -C _b install >>"$LOG" 2>&1) || die "xkeyboard-config failed"

say "xorg-server"
xs=$(unpack "$(fetch main/x/xorg-server/xorg-server_21.1.26.orig.tar.gz 023f05307350a3645084353c81bfb62fe9b9afe2b5e885cabc0892ae87de1f31)")
xil=$(unpack "$(fetch main/x/xserver-xorg-input-libinput/xserver-xorg-input-libinput_1.5.0.orig.tar.gz 936ce0ad647b49eb332c7d72945e346ffc61d48a45a009e3f0403a90dbf5908e)")
python3 "$PORTS/xorg/static-drivers.py" "$xs" "$xil" >>"$LOG" 2>&1 || die "patching xorg-server failed"
(cd "$xs" && CFLAGS="$CFLAGS -DFLINT_STATIC_DRIVERS" meson setup _b --cross-file "$WORK/meson-cross.txt" --prefix=/usr --buildtype=release \
    --default-library=static --prefer-static -Db_staticpic=false \
    -Dxorg=true -Dxephyr=false -Dxnest=false -Dxvfb=false -Dxwin=false -Dxquartz=false \
    -Dglamor=false -Dglx=false -Ddri1=false -Ddri2=false -Ddri3=false -Dudev=false -Dudev_kms=false \
    -Dhal=false -Dsystemd_logind=false -Dsuid_wrapper=false -Dint10=false -Dvgahw=false -Dpciaccess=true \
    -Dxdmcp=false -Dsecure-rpc=false -Dlisten_tcp=false -Dxselinux=false -Dlinux_acpi=false -Dlinux_apm=false \
    -Dsha1=libmd -Ddocs=false -Ddevel-docs=false -Dxkb_dir=/usr/share/X11/xkb -Dxkb_output_dir=/var/lib/xkb \
    -Dxkb_bin_dir=/usr/bin -Ddefault_font_path=built-ins -Dlog_dir=/var/log -Dmodule_dir=/usr/lib/xorg/modules >>"$LOG" 2>&1 \
    && ninja -C _b -j"$JOBS" >>"$LOG" 2>&1 && DESTDIR="$STAGE" ninja -C _b install >>"$LOG" 2>&1) || die "xorg-server failed"
file "$STAGE/usr/bin/Xorg" | grep -q "statically linked" || die "Xorg is not static"

# what a package does not need: headers, pkgconfig files, man pages, the SDK
rm -rf "$STAGE/usr/include" "$STAGE/usr/lib/pkgconfig" "$STAGE/usr/share/pkgconfig" "$STAGE/usr/share/man" \
    "$STAGE/usr/share/aclocal" "$STAGE/usr/lib/xorg" "$STAGE/usr/share/doc" "$STAGE/usr/bin/gtf" "$STAGE/usr/bin/cvt"
cp -R "$PORTS/xorg/files"/. "$STAGE"/
# what every X program reads at run time: fontconfig's configuration and Xlib's locale data
cp -R "$SYSROOT/runtime"/. "$STAGE"/
mkdir -p "$STAGE/usr/share/libinput"
cp "$SYSROOT/share/libinput"/*.quirks "$STAGE/usr/share/libinput/"
for t in fc-cache fc-list fc-match; do cp "$SYSROOT/bin/$t" "$STAGE/usr/bin/"; done
chmod 755 "$STAGE/usr/bin/startx"
mkdir -p "$STAGE/usr/share/licenses/xorg" "$STAGE/var/lib/xkb"
cp "$xs/COPYING" "$STAGE/usr/share/licenses/xorg/COPYING.xserver"
cp "$xil/COPYING" "$STAGE/usr/share/licenses/xorg/COPYING.xf86-input-libinput"
cp "$xkc/COPYING" "$STAGE/usr/share/licenses/xorg/COPYING.xkeyboard-config"
ports_package 21.1.26.2 "X.Org X server with built-in modesetting and libinput drivers, keyboard layouts, startx" \
    etc/X11/xinit/xinitrc etc/fonts/fonts.conf
