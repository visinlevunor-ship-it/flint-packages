#!/bin/sh
# procs: modern ps with colors and search (static Rust build of the procs crate).
# Usage: ports/procs/build.sh OUTDIR. Needs cargo (with rust-src if rustup has no musl target).
. "$(dirname "$0")/../common.sh"
ports_init procs "${1:?usage: build.sh OUTDIR}"
rust_crate procs 0.14.12
ports_package 0.14.12 "Modern ps with colors and search"
