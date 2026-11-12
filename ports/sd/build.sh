#!/bin/sh
# sd: intuitive find and replace (sed for humans) (static Rust build of the sd crate).
# Usage: ports/sd/build.sh OUTDIR. Needs cargo (with rust-src if rustup has no musl target).
. "$(dirname "$0")/../common.sh"
ports_init sd "${1:?usage: build.sh OUTDIR}"
rust_crate sd 1.0.0
ports_package 1.0.0 "Intuitive find and replace (sed for humans)"
