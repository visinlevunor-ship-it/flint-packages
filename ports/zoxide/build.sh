#!/bin/sh
# zoxide: smarter cd that remembers where you go (z) (static Rust build of the zoxide crate).
# Usage: ports/zoxide/build.sh OUTDIR. Needs cargo (with rust-src if rustup has no musl target).
. "$(dirname "$0")/../common.sh"
ports_init zoxide "${1:?usage: build.sh OUTDIR}"
rust_crate zoxide 0.10.0
ports_package 0.10.0 "Smarter cd that remembers where you go (z)"
