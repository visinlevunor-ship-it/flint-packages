#!/bin/sh
# hyperfine: command-line benchmarking (static Rust build of the hyperfine crate).
# Usage: ports/hyperfine/build.sh OUTDIR. Needs cargo (with rust-src if rustup has no musl target).
. "$(dirname "$0")/../common.sh"
ports_init hyperfine "${1:?usage: build.sh OUTDIR}"
rust_crate hyperfine 2.0.0
ports_package 2.0.0 "Command-line benchmarking"
