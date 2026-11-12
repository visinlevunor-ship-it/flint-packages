#!/bin/sh
# tokei: count lines of code by language (static Rust build of the tokei crate).
# Usage: ports/tokei/build.sh OUTDIR. Needs cargo (with rust-src if rustup has no musl target).
. "$(dirname "$0")/../common.sh"
ports_init tokei "${1:?usage: build.sh OUTDIR}"
rust_crate tokei 15.0.0
ports_package 15.0.0 "Count lines of code by language"
