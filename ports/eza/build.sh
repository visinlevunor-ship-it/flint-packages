#!/bin/sh
# eza: modern ls with colors, icons and a tree view (static Rust build of the eza crate).
# Usage: ports/eza/build.sh OUTDIR. Needs cargo (with rust-src if rustup has no musl target).
. "$(dirname "$0")/../common.sh"
ports_init eza "${1:?usage: build.sh OUTDIR}"
rust_crate eza 0.23.5
ports_package 0.23.5 "Modern ls with colors, icons and a tree view"
