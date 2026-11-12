# Shared by the ports/*/build.sh recipes (sourced, not run).
#
# Sources are the upstream release tarballs as Ubuntu's archive keeps them (pinned by
# SHA-256; Launchpad keeps every file if the mirror drops one). Everything is built as
# static x86-64 musl binaries with zig (`zig cc -target x86_64-linux-musl`): from
# PATH, or the `ziglang` Python package (pip install ziglang). Needs a Linux build host
# (configure scripts run what they compile) with make, perl, xz, bzip2, autoconf, automake,
# bison, pkg-config and file, and tic for the
# terminal descriptions built into ncurses.
#
# A recipe calls: ports_init NAME OUTDIR, the lib_* it needs, its own build into
# "$STAGE" (the package's files), then ports_package VERSION DESCRIPTION [CONFIG...].

set -eu

PORTS=$(cd "$(dirname "$0")/.." && pwd)
CACHE=${CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/flint-ports}
UBUNTU=${UBUNTU_MIRROR:-https://archive.ubuntu.com/ubuntu}
LAUNCHPAD=https://launchpad.net/ubuntu/+archive/primary/+files
JOBS=${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}

say() { printf '%s\n' "== $*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else sha256 -q "$1"; fi
}

# fetch POOL_PATH SHA256 -> prints the cached file. POOL_PATH is under Ubuntu's pool/.
fetch() {
    mkdir -p "$CACHE"
    f="$CACHE/$(basename "$1")"
    if [ ! -f "$f" ] || [ "$(sha256_of "$f")" != "$2" ]; then
        say "downloading $(basename "$1")"
        curl -fsSL -o "$f.part" "$UBUNTU/pool/$1" || curl -fsSL -o "$f.part" "$LAUNCHPAD/$(basename "$1")" || die "cannot download $1"
        mv "$f.part" "$f"
    fi
    got=$(sha256_of "$f")
    [ "$got" = "$2" ] || { rm -f "$f"; die "$(basename "$1"): checksum mismatch (got $got)"; }
    echo "$f"
}

# unpack ARCHIVE -> prints the directory it unpacked to (inside $WORK/src)
unpack() {
    d="$WORK/src/$(basename "$1" | sed 's/\.orig\.tar\..*//; s/\.tar\..*//')"
    rm -rf "$d"
    mkdir -p "$d"
    tar -xf "$1" -C "$d"
    # most tarballs have one top directory
    n=$(ls "$d" | wc -l)
    if [ "$n" -eq 1 ] && [ -d "$d/$(ls "$d")" ]; then echo "$d/$(ls "$d")"; else echo "$d"; fi
}

toolchain() {
    BIN="$WORK/bin"
    mkdir -p "$BIN"
    if command -v zig >/dev/null 2>&1; then
        ZIG=$(command -v zig)
    elif ZDIR=$(python3 -c 'import ziglang, os; print(os.path.dirname(ziglang.__file__))' 2>/dev/null); then
        ZIG="$ZDIR/zig"
    else
        die "zig not found (install zig, or: pip install ziglang)"
    fi
    for t in cc c++; do
        # (Rust's cc crate adds a --target= of its own, which zig does not take)
        printf '#!/bin/sh\nfor a; do shift; case "$a" in --target=*) ;; *) set -- "$@" "$a" ;; esac; done\nexec "%s" %s -target x86_64-linux-musl "$@"\n' "$ZIG" "$t" > "$BIN/x86_64-linux-musl-$t"
    done
    printf '#!/bin/sh\nexec "%s" ar "$@"\n' "$ZIG" > "$BIN/x86_64-linux-musl-ar"
    printf '#!/bin/sh\nexec "%s" ranlib "$@"\n' "$ZIG" > "$BIN/x86_64-linux-musl-ranlib"
    printf '#!/bin/sh\nexit 0\n' > "$BIN/x86_64-linux-musl-strip"
    chmod +x "$BIN"/*
    ln -sf x86_64-linux-musl-cc "$BIN/x86_64-linux-musl-gcc"
    export PATH="$BIN:$PATH"
    export CC=x86_64-linux-musl-cc CXX=x86_64-linux-musl-c++ AR=x86_64-linux-musl-ar RANLIB=x86_64-linux-musl-ranlib
    export CFLAGS="-Os -ffunction-sections -fdata-sections -I$SYSROOT/include"
    export CXXFLAGS="$CFLAGS"
    export CPPFLAGS="-I$SYSROOT/include"
    export LDFLAGS="-static -Wl,--gc-sections -L$SYSROOT/lib"
    export PKG_CONFIG_PATH="$SYSROOT/lib/pkgconfig" PKG_CONFIG_LIBDIR="$SYSROOT/lib/pkgconfig"
    HOSTFLAGS="--host=x86_64-linux-musl --build=x86_64-pc-linux-gnu"
}

ports_init() { # NAME OUTDIR
    NAME=$1
    OUT=$2
    WORK=${WORK:-$(mktemp -d "${TMPDIR:-/tmp}/flint-port-$NAME.XXXXXX")}
    mkdir -p "$WORK"
    SYSROOT="$WORK/sysroot"
    STAGE="$WORK/stage"
    LOG="$WORK/build.log"
    : > "$LOG"
    trap 'st=$?; if [ $st -ne 0 ]; then echo "build failed; the end of $LOG:" >&2; tail -n 40 "$LOG" >&2; fi' EXIT
    rm -rf "$STAGE"
    mkdir -p "$SYSROOT/include" "$SYSROOT/lib" "$STAGE" "$WORK/src"
    toolchain
}

# The package source tree: OUT/control and OUT/files (= $STAGE, stripped).
ports_package() { # VERSION DESCRIPTION [CONFIG-FILE...]
    version=$1 desc=$2
    shift 2
    for f in $(find "$STAGE" -type f -perm -u+x); do
        if head -c 4 "$f" | grep -q 'ELF'; then
            strip "$f" 2>/dev/null || true
            if file "$f" | grep -q 'dynamically linked'; then
                # only musl-linked programs, in packages that say so (they depend on musl)
                [ -n "${ALLOW_DYNAMIC:-}" ] && file "$f" | grep -qE 'interpreter /lib/ld-musl-x86_64.so.1|shared object' \
                    || die "$f is not static"
            fi
        fi
    done
    rm -rf "$OUT"
    mkdir -p "$OUT"
    cp -R "$STAGE" "$OUT/files"
    {
        echo "name: $NAME"
        echo "version: $version"
        echo "description: $desc"
        echo "arch: x86_64"
        [ $# -gt 0 ] && echo "config: $*"
    } > "$OUT/control"
    say "staged $NAME $version in $OUT (pkg build $OUT REPO)"
}

# ---- libraries, built into $SYSROOT ----------------------------------------------------

lib_ncurses() {
    src=$(unpack "$(fetch main/n/ncurses/ncurses_6.6+20260608.orig.tar.gz 3b91eb714ba61b9ebfcfe09cf8e7c1c45cf2e8a6282f5887fb942db514ae93bd)")
    say "ncurses"
    # The common terminals are built in, so no terminfo files are needed for them.
    (cd "$src" && ./configure $HOSTFLAGS --prefix="$SYSROOT" --without-shared --without-debug \
        --without-ada --without-cxx --without-cxx-binding --without-manpages --without-tests --without-progs \
        --enable-widec --disable-db-install --without-pkg-config \
        --with-fallbacks=linux,vt100,vt220,xterm,xterm-256color,screen,screen-256color,tmux,tmux-256color,alacritty,foot,kitty,st-256color \
        --with-default-terminfo-dir=/usr/share/terminfo --with-terminfo-dirs=/etc/terminfo:/usr/share/terminfo \
        >>"$LOG" 2>&1 && make -j"$JOBS" >>"$LOG" 2>&1 && make install.libs install.includes >>"$LOG" 2>&1)
    # many configure scripts look for -lncurses / ncurses.h without the w
    for l in ncurses tinfo curses; do ln -sf libncursesw.a "$SYSROOT/lib/lib$l.a"; done
    ln -sf ncursesw/curses.h "$SYSROOT/include/curses.h"
    ln -sf ncursesw/ncurses.h "$SYSROOT/include/ncurses.h"
    ln -sf ncursesw/term.h "$SYSROOT/include/term.h"
}

lib_zlib() {
    src=$(unpack "$(fetch main/z/zlib/zlib_1.3.dfsg+really1.3.2.orig.tar.gz 7b6903eb019983987b7112eccf90f1703f1c6c0e0cede36564bf611d19ca579d)")
    say "zlib"
    (cd "$src" && CHOST=x86_64-linux-musl ./configure --static --prefix="$SYSROOT" >>"$LOG" 2>&1 && make -j"$JOBS" libz.a >>"$LOG" 2>&1 && make install >>"$LOG" 2>&1)
}

lib_libevent() {
    src=$(unpack "$(fetch main/libe/libevent/libevent_2.1.13-stable.orig.tar.gz f7e9383b8c0baa81b687e5b5eecc01beefaf1b19b64151d95ed61647fe7a315c)")
    say "libevent"
    (cd "$src" && ./configure $HOSTFLAGS --prefix="$SYSROOT" --disable-shared --enable-static --disable-openssl \
        --disable-samples --disable-libevent-regress --disable-debug-mode >>"$LOG" 2>&1 && make -j"$JOBS" >>"$LOG" 2>&1 && make install >>"$LOG" 2>&1)
}

lib_mbedtls() {
    src=$(unpack "$(fetch universe/m/mbedtls/mbedtls_3.6.7.orig.tar.bz2 a7e8bcbec0e6f761b4af24f25677626b35f762f68eef79c08677a363212d11f6)")
    say "mbedtls"
    (cd "$src" && make -j"$JOBS" lib CC="$CC" AR="$AR" CFLAGS="$CFLAGS" >>"$LOG" 2>&1 && make install DESTDIR="$SYSROOT" >>"$LOG" 2>&1)
}

lib_curl() { # needs lib_zlib lib_mbedtls
    src=$(unpack "$(fetch main/c/curl/curl_8.23.0.orig.tar.gz e3de77cfa6367083c776a26647fc9f633b538c06c3baa73d931a252ac8f72b49)")
    say "curl"
    (cd "$src" && ./configure $HOSTFLAGS --prefix="$SYSROOT" --disable-shared --enable-static \
        --with-mbedtls="$SYSROOT" --with-zlib="$SYSROOT" --without-libpsl --without-brotli --without-zstd \
        --without-libidn2 --without-nghttp2 --without-libssh2 --disable-ldap --disable-ldaps --disable-rtsp \
        --disable-dict --disable-telnet --disable-tftp --disable-pop3 --disable-imap --disable-smtp \
        --disable-gopher --disable-mqtt --disable-manual --disable-docs \
        --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt --with-ca-path=/etc/ssl/certs \
        >>"$LOG" 2>&1 && make -j"$JOBS" >>"$LOG" 2>&1 && make install >>"$LOG" 2>&1)
}

lib_popt() {
    src=$(unpack "$(fetch main/p/popt/popt_1.19+dfsg.orig.tar.xz 4cd0cd2963d0c4078f65949599d97135c15ee6c09cf3a36a9a1b2753025bb06b)")
    say "popt"
    (cd "$src" && { [ -x configure ] || autoreconf -fi >>"$LOG" 2>&1; } && ./configure $HOSTFLAGS --prefix="$SYSROOT" --disable-shared --enable-static --disable-nls \
        >>"$LOG" 2>&1 && make -j"$JOBS" -C src >>"$LOG" 2>&1 && make -C src install >>"$LOG" 2>&1)
}

# ---- Rust and Go programs ---------------------------------------------------------------

# rust_crate CRATE VERSION [cargo install options...]: installs the crate's binaries into
# $STAGE/usr/bin, built for x86_64-unknown-linux-musl (static) with the crate's own
# Cargo.lock; crates.io checks every crate's SHA-256. Without rustup's musl target, std is
# built from source (rust-src) and linked with zig.
rust_crate() {
    crate=$1 cver=$2
    shift 2
    command -v cargo >/dev/null 2>&1 || die "cargo not found"
    say "$crate $cver"
    rt=x86_64-unknown-linux-musl
    set -- --locked --version "$cver" --root "$WORK/cargo-root" --target "$rt" "$@"
    export CARGO_TARGET_DIR="$WORK/cargo-target" CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER="$BIN/x86_64-linux-musl-cc"
    export CC_x86_64_unknown_linux_musl="$CC" CXX_x86_64_unknown_linux_musl="$CXX" AR_x86_64_unknown_linux_musl="$AR"
    if rustup target list --installed 2>/dev/null | grep -qx "$rt"; then
        RUSTFLAGS="-C target-feature=+crt-static" cargo install "$@" "$crate" >>"$LOG" 2>&1
    else
        RUSTC_BOOTSTRAP=1 RUSTFLAGS="-C target-feature=+crt-static -C link-self-contained=no" \
            cargo install -Zbuild-std=std,panic_abort "$@" "$crate" >>"$LOG" 2>&1
    fi
    mkdir -p "$STAGE/usr/bin"
    cp "$WORK/cargo-root/bin/"* "$STAGE/usr/bin/"
    # the license files from the crate's source in cargo's registry
    lic=$(ls -d "${CARGO_HOME:-$HOME/.cargo}"/registry/src/*/"$crate-$cver" 2>/dev/null | head -n 1)
    mkdir -p "$STAGE/usr/share/licenses/$NAME"
    [ -n "$lic" ] && cp "$lic"/LICENSE* "$lic"/COPYING* "$lic"/UNLICENSE* "$STAGE/usr/share/licenses/$NAME/" 2>/dev/null || true
}

# git_clone REPO TAG COMMIT DIR: a GitHub repository at a tag, checked against the commit.
git_clone() {
    git -c advice.detachedHead=false clone -q --depth 1 --branch "$2" "https://github.com/$1.git" "$4" >>"$LOG" 2>&1 || die "cannot clone $1"
    got=$(git -C "$4" rev-parse HEAD)
    [ "$got" = "$3" ] || die "$1 $2 is commit $got, expected $3"
}

# go_program DIR PACKAGE OUTPUT [ldflags]: a static Go build of PACKAGE in the module at DIR.
# Modules are checked against the module's go.sum. When the Go module proxy cannot be reached
# (GO_MIRROR=1), golang.org/x modules come from their GitHub mirrors (github.com/golang/NAME)
# at the versions go.mod asks for, and the rest straight from their repositories.
go_program() {
    command -v go >/dev/null 2>&1 || die "go not found"
    gdir=$1 gpkg=$2 gout=$3 gld=${4:-}
    export GOPATH="$WORK/gopath" GOCACHE="$WORK/gocache" GOFLAGS=-mod=mod CGO_ENABLED=0 GOOS=linux GOARCH=amd64
    if [ -n "${GO_MIRROR:-}" ]; then
        export GOPROXY=direct
        grep -E '^\s*golang\.org/x/[a-z]+ v' "$gdir/go.mod" | awk '{print $1, $2}' | sort -u | while read -r mod ver; do
            n=${mod#golang.org/x/}
            d="$WORK/gox/$n"
            [ -d "$d" ] && continue
            case "$ver" in
                v0.0.0-*) rev=${ver##*-}
                          git clone -q "https://github.com/golang/$n.git" "$d" >>"$LOG" 2>&1 && git -C "$d" checkout -q "$rev" ;;
                *)        git -c advice.detachedHead=false clone -q --depth 1 --branch "$ver" "https://github.com/golang/$n.git" "$d" >>"$LOG" 2>&1 ;;
            esac || die "cannot fetch $mod $ver"
            (cd "$gdir" && go mod edit -replace "$mod=$d")
        done
    fi
    (cd "$gdir" && go build -trimpath -ldflags "-s -w $gld" -o "$gout" "$gpkg") >>"$LOG" 2>&1 || die "go build $gpkg failed"
    chmod -R u+w "$WORK/gopath" 2>/dev/null || true
}
