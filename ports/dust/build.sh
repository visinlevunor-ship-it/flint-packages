#!/bin/sh
# dust: intuitive du: what takes the space, as a tree (static Rust build of the du-dust crate).
# Usage: ports/dust/build.sh OUTDIR. Needs cargo (with rust-src if rustup has no musl target).
. "$(dirname "$0")/../common.sh"
ports_init dust "${1:?usage: build.sh OUTDIR}"
rust_crate du-dust 1.2.7
ports_package 1.2.7 "Intuitive du: what takes the space, as a tree"
