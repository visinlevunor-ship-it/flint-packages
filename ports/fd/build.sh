#!/bin/sh
# fd: simple, fast alternative to find (static Rust build of the fd-find crate).
# Usage: ports/fd/build.sh OUTDIR. Needs cargo (with rust-src if rustup has no musl target).
. "$(dirname "$0")/../common.sh"
ports_init fd "${1:?usage: build.sh OUTDIR}"
rust_crate fd-find 10.5.2
ports_package 10.5.2 "Simple, fast alternative to find"
