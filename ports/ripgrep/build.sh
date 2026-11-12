#!/bin/sh
# ripgrep: fast recursive search (rg), respects .gitignore (static Rust build of the ripgrep crate).
# Usage: ports/ripgrep/build.sh OUTDIR. Needs cargo (with rust-src if rustup has no musl target).
. "$(dirname "$0")/../common.sh"
ports_init ripgrep "${1:?usage: build.sh OUTDIR}"
rust_crate ripgrep 15.2.0
ports_package 15.2.0 "Fast recursive search (rg), respects .gitignore"
