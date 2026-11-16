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
        case "$1" in
            http://*|https://*) curl -fsSL -o "$f.part" "$1" || die "cannot download $1" ;;
            *) curl -fsSL -o "$f.part" "$UBUNTU/pool/$1" || curl -fsSL -o "$f.part" "$LAUNCHPAD/$(basename "$1")" || die "cannot download $1" ;;
        esac
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
    # zig's own malloc (zig 0.15 and later) returns NULL from realloc(p, 0), which C programs
    # take for "out of memory" (Xorg does). Every program is linked with realloc and
    # reallocarray wrapped so that zero bytes is a small block, as in musl.
    cat > "$BIN/realloc0.c" <<'EOC'
#include <errno.h>
#include <stddef.h>
void *__real_realloc(void *, size_t);
void *__wrap_realloc(void *p, size_t n) { return __real_realloc(p, n ? n : 1); }
void *__wrap_reallocarray(void *p, size_t m, size_t n)
{
	if (n && m > (size_t)-1 / n) {
		errno = ENOMEM;
		return NULL;
	}
	return __wrap_realloc(p, m * n);
}
EOC
    "$ZIG" cc -target x86_64-linux-musl -Os -c -o "$BIN/realloc0.o" "$BIN/realloc0.c" || die "cannot build realloc0.o"
    for t in cc c++; do
        # Rust's cc crate adds a --target= of its own, which zig does not take; with -E, zig
        # compiles instead of preprocessing when -c is given too (meson passes both); and a
        # link gets the realloc wrapper above
        cat > "$BIN/x86_64-linux-musl-$t" <<EOC
#!/bin/sh
e=0 link=1
for a; do
    case "\$a" in
        -E) e=1 link=0 ;;
        -c|-S|-M|-MM|-r|-shared|-v|--version|-dumpversion|-dumpmachine|-print-*|--print-*) link=0 ;;
    esac
done
for a; do
    shift
    case "\$a" in
        --target=*) ;;
        -c) [ \$e = 1 ] || set -- "\$@" "\$a" ;;
        *) set -- "\$@" "\$a" ;;
    esac
done
[ \$link = 1 ] && set -- "\$@" "$BIN/realloc0.o" -Wl,--wrap=realloc -Wl,--wrap=reallocarray
exec "$ZIG" $t -target x86_64-linux-musl "\$@"
EOC
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
# With GLIBC=1 the files are Ubuntu's prebuilt ones (deb_unpack_list): left as they are, and
# programs may name glibc's loader (flint-glibc) as their interpreter.
ports_package() { # VERSION DESCRIPTION [CONFIG-FILE...]
    version=$1 desc=$2
    shift 2
    for f in $(find "$STAGE" -type f -perm -u+x); do
        [ -n "${GLIBC:-}" ] && break
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
        [ $# -gt 0 ] && echo "config: $(echo "$*" | sed 's/ /, /g')"
    } > "$OUT/control"
    say "staged $NAME $version in $OUT (pkg build $OUT REPO)"
}

# ports_split MAX_KIB: a package too big for one file in git (GitHub refuses files over
# 100 MB) is split: OUT-1, OUT-2... (packages NAME-1, NAME-2...) take whole files and
# directories up to MAX_KIB compressed each, and NAME keeps the rest and depends on them at
# its own version, so installing NAME brings everything. Configuration files stay in NAME.
# Build each directory with pkg build.
ports_split() { # MAX_KIB
    max=$1
    configs=$(sed -n 's/^config: //p' "$OUT/control" | tr ',' '\n' | sed 's/^ *\/*//')
    version=$(sed -n 's/^version: //p' "$OUT/control")
    desc=$(sed -n 's/^description: //p' "$OUT/control")
    gzkib() { tar -cf - -C "$OUT/files" "$1" 2>/dev/null | gzip -6 | wc -c | awk '{print int(($1 + 1023) / 1024)}'; }
    # units: paths (relative to files/) small enough for a part
    : > "$WORK/units"
    walk() {
        holds_config=""
        for c in $configs; do
            [ "$c" = "$1" ] && return 0
            case "$c" in "$1"/*) holds_config=1 ;; esac
        done
        k=$(gzkib "$1")
        if { [ "$k" -gt "$max" ] || [ -n "$holds_config" ]; } && [ -d "$OUT/files/$1" ]; then
            for e in $(cd "$OUT/files/$1" && ls -A | LC_ALL=C sort); do walk "$1/$e"; done
        else
            [ "$k" -gt 95000 ] && die "$1 is $k KiB compressed: too big for one package"
            printf '%s\t%s\n' "$k" "$1" >> "$WORK/units"
        fi
    }
    for e in $(cd "$OUT/files" && ls -A | LC_ALL=C sort); do walk "$e"; done
    total=$(awk -F'\t' '{s += $1} END {print s + 0}' "$WORK/units")
    [ "$total" -le "$max" ] && return 0
    # biggest first, into the first part with room
    sort -rn "$WORK/units" > "$WORK/units.sorted"
    n=0
    deps=""
    while IFS="$(printf '\t')" read -r k rel; do
        i=1 placed=""
        while [ "$i" -le "$n" ]; do
            used=$(cat "$WORK/part$i.kib")
            if [ $((used + k)) -le "$max" ]; then placed=$i; break; fi
            i=$((i + 1))
        done
        if [ -z "$placed" ]; then
            n=$((n + 1))
            placed=$n
            echo 0 > "$WORK/part$n.kib"
            rm -rf "$OUT-$n"
            mkdir -p "$OUT-$n/files"
            printf 'name: %s\nversion: %s\ndescription: %s (part %s)\narch: x86_64\n' "$NAME-$n" "$version" "$desc" "$n" > "$OUT-$n/control"
            deps="${deps:+$deps, }$NAME-$n=$version"
        fi
        echo $(( $(cat "$WORK/part$placed.kib") + k )) > "$WORK/part$placed.kib"
        mkdir -p "$(dirname "$OUT-$placed/files/$rel")"
        mv "$OUT/files/$rel" "$OUT-$placed/files/$rel"
    done < "$WORK/units.sorted"
    # NAME itself: a small file naming its parts, so it is never empty
    mkdir -p "$OUT/files/usr/share/licenses/$NAME"
    printf '%s\n' "$n" > "$OUT/files/usr/share/licenses/$NAME/parts"
    if grep -q '^depends: ' "$OUT/control"; then
        sed -i.bak "s/^depends: \(.*\)/depends: \1, $deps/" "$OUT/control" && rm -f "$OUT/control.bak"
    else
        printf 'depends: %s\n' "$deps" >> "$OUT/control"
    fi
    say "split $NAME into $n parts ($OUT-1 ... $OUT-$n) and $OUT"
}

# ---- Ubuntu binary packages (programs built for glibc, run by flint-glibc) ----------------

# deb_unpack_list LIST [DEST]: fetch each package LIST names ("POOL_PATH SHA256 NAME VERSION"
# lines, made by ports/deb-closure.py) and unpack its files into DEST (default $STAGE).
# Documentation is dropped; each package's copyright file goes to
# /usr/share/licenses/$NAME/PACKAGE.
deb_unpack_list() { # LIST [DEST]
    dest=${2:-$STAGE}
    while read -r pool sum pkg ver; do
        case "$pool" in ''|'#'*) continue ;; esac
        deb_unpack "$pool" "$sum" "$dest"
    done < "$1"
}

deb_unpack() { # POOL_PATH SHA256 [DEST]
    f=$(fetch "$1" "$2")
    dest=${3:-$STAGE}
    d="$WORK/deb/$(basename "$1" .deb)"
    rm -rf "$d"
    mkdir -p "$d/x"
    (cd "$d" && ar x "$f") || die "cannot read $(basename "$1")"
    tar -xf "$d"/data.tar.* -C "$d/x" || die "cannot unpack $(basename "$1")"
    pkg=$(basename "$1" | cut -d_ -f1)
    if [ -f "$d/x/usr/share/doc/$pkg/copyright" ]; then
        mkdir -p "$dest/usr/share/licenses/$NAME"
        cp "$d/x/usr/share/doc/$pkg/copyright" "$dest/usr/share/licenses/$NAME/$pkg"
    fi
    rm -rf "$d/x/usr/share/doc" "$d/x/usr/share/man" "$d/x/usr/share/lintian" "$d/x/usr/share/bug" \
        "$d/x/usr/share/info" "$d/x/usr/share/doc-base"
    (cd "$d/x" && tar -cf - .) | (cd "$dest" && tar -xf -)
    rm -rf "$d"
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

# ---- X11 -------------------------------------------------------------------------------

# A meson cross file for the zig toolchain (meson needs one to build for musl).
meson_cross() {
    [ -f "$WORK/meson-cross.txt" ] && return 0
    cat > "$WORK/meson-cross.txt" <<EOC
[binaries]
c = '$BIN/x86_64-linux-musl-cc'
cpp = '$BIN/x86_64-linux-musl-c++'
ar = '$BIN/x86_64-linux-musl-ar'
ranlib = '$BIN/x86_64-linux-musl-ranlib'
strip = '$BIN/x86_64-linux-musl-strip'
pkg-config = 'pkg-config'

[properties]
needs_exe_wrapper = false

[host_machine]
system = 'linux'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOC
}

# meson_lib SRC [meson options...]: a static library into $SYSROOT
meson_lib() {
    msrc=$1
    shift
    meson_cross
    rm -rf "$msrc/_b"
    (cd "$msrc" && meson setup _b --cross-file "$WORK/meson-cross.txt" --prefix="$SYSROOT" --libdir=lib \
        --default-library=static --prefer-static --buildtype=release -Db_staticpic=false "$@" >>"$LOG" 2>&1 \
        && ninja -C _b -j"$JOBS" >>"$LOG" 2>&1 && ninja -C _b install >>"$LOG" 2>&1) || die "$(basename "$msrc") failed"
}

# ac_lib SRC [configure options...]: an autotools static library into $SYSROOT
ac_lib() {
    asrc=$1
    shift
    (cd "$asrc" && { [ -x configure ] || autoreconf -fi >>"$LOG" 2>&1; } \
        && xorg_cv_malloc0_returns_null=no ./configure $HOSTFLAGS --prefix="$SYSROOT" --disable-shared --enable-static "$@" >>"$LOG" 2>&1 \
        && make -j"$JOBS" >>"$LOG" 2>&1 && make install >>"$LOG" 2>&1) || die "$(basename "$asrc") failed"
}

# runtime_split DIR: DIR holds a DESTDIR install made with --prefix=$SYSROOT. The library
# goes into $SYSROOT; what programs read at run time from fixed paths (/etc/fonts,
# /usr/share/X11/locale) goes into $SYSROOT/runtime, for the xorg package to ship.
runtime_split() {
    cp -R "$1$SYSROOT"/. "$SYSROOT"/
    mkdir -p "$SYSROOT/runtime"
    tar -C "$1" --exclude="./${SYSROOT#/}" -cf - . | tar -C "$SYSROOT/runtime" -xf -
    rm -rf "$1" "$SYSROOT/runtime/usr/share/man" "$SYSROOT/runtime/usr/share/doc" "$SYSROOT/runtime/tmp" "$SYSROOT/runtime/root"
}

X11_CLIENT_LIBS="zlib expat freetype fontconfig xorgproto xcbproto xau xdmcp xcb xtrans x11 xext xrender xfixes xinerama xft"

lib_expat() {
    # a git snapshot: the library is in expat/, and configure is generated
    ac_lib "$(unpack "$(fetch main/e/expat/expat_2.10.0.orig.tar.gz b3644a12f62d7762b62c444f69d169ba0234f13138d0240244bca64cbe35286f)")/expat" \
        --without-docbook --without-examples --without-tests --without-xmlwf
}
lib_freetype() {
    ac_lib "$(unpack "$(fetch main/f/freetype/freetype_2.14.3+dfsg.orig.tar.xz dc1bec263a6fffa436029efe6428f601d6b1a0b800837508ee3e49bbab8f1006)")" \
        --with-zlib --without-bzip2 --without-png --without-harfbuzz --without-brotli
}
lib_fontconfig() {
    fsrc=$(unpack "$(fetch main/f/fontconfig/fontconfig_2.17.1.orig.tar.gz f07504cef87f171ee1748352e2df9b9f125352f620fa0d03a9284306ea2c40a4)")
    meson_cross
    rm -rf "$fsrc/_b"
    # its configuration lives in /etc/fonts: installed under DESTDIR, never on the build machine
    (cd "$fsrc" && meson setup _b --cross-file "$WORK/meson-cross.txt" --prefix="$SYSROOT" --libdir=lib \
        --default-library=static --prefer-static --buildtype=release -Db_staticpic=false \
        -Ddoc=disabled -Dtests=disabled -Dtools=enabled -Dcache-build=disabled -Dnls=disabled \
        -Ddefault-fonts-dirs=/usr/share/fonts -Dcache-dir=/var/cache/fontconfig -Dbaseconfig-dir=/etc/fonts \
        -Dconfig-dir=/etc/fonts/conf.d -Dtemplate-dir=/usr/share/fontconfig/conf.avail -Dxml-backend=expat >>"$LOG" 2>&1 \
        && ninja -C _b -j"$JOBS" >>"$LOG" 2>&1 && DESTDIR="$WORK/rt-fontconfig" ninja -C _b install >>"$LOG" 2>&1) \
        || die "fontconfig failed"
    runtime_split "$WORK/rt-fontconfig"
}
lib_xorgproto() {
    meson_lib "$(unpack "$(fetch main/x/xorgproto/xorgproto_2025.1.orig.tar.gz d6f89f65bafb8c9b735e0515882b8a1511e8e864dde5e9513e191629369f2256)")" -Dlegacy=false
}
lib_xcbproto() {
    ac_lib "$(unpack "$(fetch universe/x/xcb-proto/xcb-proto_1.17.0.orig.tar.gz 392d3c9690f8c8202a68fdb89c16fd55159ab8d65000a6da213f4a1576e97a16)")"
}
lib_xau() {
    ac_lib "$(unpack "$(fetch main/libx/libxau/libxau_1.0.11.orig.tar.gz 3a321aaceb803577a4776a5efe78836eb095a9e44bbc7a465d29463e1a14f189)")"
}
lib_xdmcp() {
    ac_lib "$(unpack "$(fetch main/libx/libxdmcp/libxdmcp_1.1.5.orig.tar.gz 31a7abc4f129dcf6f27ae912c3eedcb94d25ad2e8f317f69df6eda0bc4e4f2f3)")" --disable-docs
}
lib_xcb() {
    # the code generator is xcb-proto's python module, installed into the sysroot above
    xpy=$(ls -d "$SYSROOT"/lib/python3*/site-packages 2>/dev/null | head -n 1)
    PYTHONPATH="$xpy" ac_lib "$(unpack "$(fetch main/libx/libxcb/libxcb_1.17.0.orig.tar.gz 2c69287424c9e2128cb47ffe92171e10417041ec2963bceafb65cb3fcf8f0b85)")" \
        --disable-devel-docs --without-doxygen --without-launchd
}
lib_xtrans() {
    ac_lib "$(unpack "$(fetch main/x/xtrans/xtrans_1.6.0.orig.tar.gz 936b74c60b19c317c3f3cb1b114575032528dbdaf428740483200ea874c2ca0a)")" --disable-docs
}
lib_x11() {
    # its data (locales for input methods and compose keys, error texts) is read from
    # /usr/share/X11 at run time: installed under DESTDIR, never on the build machine
    xsrc=$(unpack "$(fetch main/libx/libx11/libx11_1.8.14.orig.tar.gz ebb8a58549ddde50aa2e742b3b256557f451053d173be8dbfc2e8ac078eee1d6)")
    (cd "$xsrc" && ./configure $HOSTFLAGS --prefix="$SYSROOT" --datadir=/usr/share --disable-shared --enable-static \
        --disable-specs --without-xmlto --without-fop --enable-xlocaledir --enable-xthreads \
        --with-locale-lib-dir=/usr/lib/X11/locale CC_FOR_BUILD=cc CPPFLAGS_FOR_BUILD= CFLAGS_FOR_BUILD= LDFLAGS_FOR_BUILD= \
        >>"$LOG" 2>&1 && make -j"$JOBS" >>"$LOG" 2>&1 && make install DESTDIR="$WORK/rt-x11" >>"$LOG" 2>&1) \
        || die "libx11 failed"
    runtime_split "$WORK/rt-x11"
}
lib_xext() {
    ac_lib "$(unpack "$(fetch main/libx/libxext/libxext_1.3.4.orig.tar.gz 8ef0789f282826661ff40a8eef22430378516ac580167da35cc948be9041aac1)")" --disable-specs --without-xmlto
}
lib_xrender() {
    ac_lib "$(unpack "$(fetch main/libx/libxrender/libxrender_0.9.13.orig.tar.gz bf264b683d1e49ff9a6bc03af13baa430a556d943731a2b1ac2439dae4fea205)")"
}
lib_xfixes() {
    ac_lib "$(unpack "$(fetch main/libx/libxfixes/libxfixes_6.0.0.orig.tar.gz 82045da5625350838390c9440598b90d69c882c324ca92f73af9f0e992cb57c7)")"
}
lib_xinerama() {
    ac_lib "$(unpack "$(fetch main/libx/libxinerama/libxinerama_1.1.4.orig.tar.gz 64de45e18cc76b8e703cb09b3c9d28bd16e3d05d5cd99f2d630de2d62c3acc18)")"
}
lib_xft() {
    ac_lib "$(unpack "$(fetch main/x/xft/xft_2.3.6.orig.tar.gz b7e59f69e0bbabe9438088775f7e5a7c16a572e58b11f9722519385d38192df5)")"
}

# The X client libraries (Xlib, Xft and what they need), built once per machine and kept in
# $CACHE, then copied into this port's sysroot.
lib_x11_clients() {
    # bump the r number when a library recipe above changes
    stamp=$(echo "$X11_CLIENT_LIBS r2" | sha256_stdin | cut -c1-16)
    xs="$CACHE/x11-clients-$stamp"
    if [ ! -f "$xs/.done" ]; then
        say "X11 client libraries (built once, kept in $xs)"
        mkdir -p "$xs/include" "$xs/lib"
        own=$SYSROOT
        SYSROOT=$xs
        export CFLAGS="-Os -ffunction-sections -fdata-sections -I$SYSROOT/include" CPPFLAGS="-I$SYSROOT/include"
        export LDFLAGS="-static -Wl,--gc-sections -L$SYSROOT/lib" PKG_CONFIG_PATH="$SYSROOT/lib/pkgconfig:$SYSROOT/share/pkgconfig"
        export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"
        for l in $X11_CLIENT_LIBS; do
            [ -f "$xs/.lib-$l" ] && continue # built by an earlier, interrupted run
            say "  $l"
            "lib_$l"
            touch "$xs/.lib-$l"
        done
        touch "$xs/.done"
        SYSROOT=$own
    fi
    cp -R "$xs"/. "$SYSROOT"/
    export CFLAGS="-Os -ffunction-sections -fdata-sections -I$SYSROOT/include" CPPFLAGS="-I$SYSROOT/include"
    export LDFLAGS="-static -Wl,--gc-sections -L$SYSROOT/lib" PKG_CONFIG_PATH="$SYSROOT/lib/pkgconfig:$SYSROOT/share/pkgconfig"
    export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"
    # .pc files point at the cache; point them here
    find "$SYSROOT/lib/pkgconfig" "$SYSROOT/share/pkgconfig" -name '*.pc' 2>/dev/null | while read -r pc; do
        sed -i.bak "s|$xs|$SYSROOT|g" "$pc" && rm -f "$pc.bak"
    done
}

sha256_stdin() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1; else sha256 -q; fi
}

# static link flags for an X client using Xft
X11_LIBS="-lXft -lfontconfig -lexpat -lfreetype -lz -lXrender -lXinerama -lXext -lX11 -lxcb -lXau -lXdmcp"
