#!/bin/sh
# bat: cat with syntax highlighting and Git integration (static Rust build of the bat crate).
# Usage: ports/bat/build.sh OUTDIR. Needs cargo (with rust-src if rustup has no musl target).
. "$(dirname "$0")/../common.sh"
ports_init bat "${1:?usage: build.sh OUTDIR}"
rust_crate bat 0.26.1
ports_package 0.26.1 "cat with syntax highlighting and Git integration"
