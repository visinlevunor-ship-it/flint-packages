#!/bin/sh
# OpenSSH client tools (static, with OpenSSH's own crypto: Ed25519 keys, ChaCha20-Poly1305,
# AES-CTR, Curve25519/ML-KEM key exchange). Usage: ports/openssh/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init openssh "${1:?usage: build.sh OUTDIR}"
lib_zlib
src=$(unpack "$(fetch main/o/openssh/openssh_10.5p1.orig.tar.xz 9643e644c20dfef1271eaccc488ae4cebc9b5352b800c30771233880d985c74c)")
say "openssh"
(cd "$src" && ./configure $HOSTFLAGS --prefix=/usr --sysconfdir=/etc/ssh --without-openssl --with-zlib="$SYSROOT" \
    --without-pam --without-selinux --without-kerberos5 --without-libedit --without-security-key-builtin \
    --with-privsep-path=/var/empty --disable-strip >>"$LOG" 2>&1 \
    && make -j"$JOBS" ssh scp sftp ssh-keygen ssh-agent ssh-add ssh-keyscan >>"$LOG" 2>&1)
mkdir -p "$STAGE/usr/bin" "$STAGE/etc/ssh" "$STAGE/usr/share/licenses/openssh"
for b in ssh scp sftp ssh-keygen ssh-agent ssh-add ssh-keyscan; do cp "$src/$b" "$STAGE/usr/bin/"; done
cp "$src/ssh_config" "$STAGE/etc/ssh/ssh_config"
cp "$src/LICENCE" "$STAGE/usr/share/licenses/openssh/"
ports_package 10.5p1 "Secure shell client: ssh, scp, sftp, ssh-keygen, ssh-agent" etc/ssh/ssh_config
