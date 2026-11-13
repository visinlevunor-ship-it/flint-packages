# Ports

Recipes that turn third-party programs into Flint packages. Each one is a POSIX shell script:

```sh
ports/NAME/build.sh OUTDIR           # stages OUTDIR/control and OUTDIR/files/
pkg build OUTDIR x86_64/             # -> x86_64/NAME-VERSION.fpk
pkg index x86_64/ && pkg sign x86_64/ ~/flint-keys/flint.key
```

Every program is built **static** for x86-64 with musl, so a package needs nothing else on the
system to run.

## Where sources come from

Every source is pinned, and a recipe refuses anything that doesn't match:

- **C programs:** release tarballs as Ubuntu's archive keeps them, checked against a SHA-256
  written in the recipe (Launchpad is the fallback mirror).
- **Rust programs:** crates from crates.io at a fixed version, built with the crate's own
  `Cargo.lock` (`--locked`). Cargo checks every crate's SHA-256.
- **Go programs:** GitHub at a tagged release, with the tag's commit checked. Modules are
  verified against the program's `go.sum`.

## What a build host needs

A Linux machine (configure scripts run what they compile) with:

- **zig**, used as the C/C++ compiler (`zig cc -target x86_64-linux-musl`); `pip install ziglang`
  also works
- make, perl, xz, bzip2, autoconf, automake, bison, pkg-config, file and tic
- **cargo** for the Rust ports. If rustup has no `x86_64-unknown-linux-musl` target, std is
  built from source instead (needs the `rust-src` component).
- **go** and **git** for the Go ports
- for the X11 ports (xorg, dwm, st, dmenu): **meson**, **ninja** and **python3**; the X
  libraries they share are built once and kept in `~/.cache/flint-ports`
- for `kernels/`: a built [flint-linux](https://github.com/visinlevunor-ship-it/flint-linux)
  checkout (`FLINT=/path/to/flint-linux`)

`common.sh` holds the shared parts: fetching and checking sources, the zig toolchain, the
libraries several ports share (ncurses, zlib, mbedTLS, curl, libevent, popt, the X client
libraries) and the Rust and
Go build steps.

## Writing a new port

Copy a recipe close to what you need:

| Kind | Example |
|---|---|
| autoconf C program | `nano`, `htop`, `strace` |
| plain Makefile | `tree`, `lua` |
| Rust crate | `ripgrep` (two lines) |
| Go program | `fzf`, `micro` |

The steps are: `ports_init NAME OUTDIR`, any `lib_*` it needs, the build into `$STAGE`, then
`ports_package VERSION "description" [config files]`. Put the program's license in
`$STAGE/usr/share/licenses/NAME/`.
