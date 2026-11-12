#!/bin/sh
# libarchive's tools (static): bsdtar (tar, zip, 7z, iso, cpio and more, read and write),
# bsdunzip (unzip), bsdcpio and bsdcat. Usage: ports/libarchive/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init libarchive "${1:?usage: build.sh OUTDIR}"
lib_zlib
src=$(unpack "$(fetch main/liba/libarchive/libarchive_3.8.11.orig.tar.xz a3dc0872b1b39da34dc18ef1b944f0f11ffd37425d70ae04be679279f1cf43d2)")
say "libarchive"
(cd "$src" && ./configure $HOSTFLAGS --prefix=/usr --disable-shared --enable-static --enable-bsdtar=static \
    --enable-bsdcpio=static --enable-bsdcat=static --enable-bsdunzip=static --disable-acl --disable-xattr \
    --without-openssl --without-xml2 --without-expat --without-lz4 --without-zstd --without-lzma --without-bz2lib \
    --without-libb2 --without-nettle --without-mbedtls --with-zlib >>"$LOG" 2>&1 \
    && make -j"$JOBS" >>"$LOG" 2>&1)
mkdir -p "$STAGE/usr/bin" "$STAGE/usr/share/licenses/libarchive"
for b in bsdtar bsdcpio bsdcat bsdunzip; do cp "$src/$b" "$STAGE/usr/bin/"; done
ln -s bsdunzip "$STAGE/usr/bin/unzip"
cp "$src/COPYING" "$STAGE/usr/share/licenses/libarchive/"
ports_package 3.8.11 "Archive tools: bsdtar (tar/zip/7z/iso), bsdunzip, bsdcpio, bsdcat"
