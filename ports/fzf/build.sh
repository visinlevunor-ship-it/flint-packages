#!/bin/sh
# fzf, the fuzzy finder (static Go build). Usage: ports/fzf/build.sh OUTDIR. Needs go and git.
. "$(dirname "$0")/../common.sh"
ports_init fzf "${1:?usage: build.sh OUTDIR}"
src="$WORK/src/fzf"
git_clone junegunn/fzf v0.75.0 c7bf2b8eea25952dd257a466c0afa72faae206fb "$src"
say "fzf"
go_program "$src" . "$WORK/fzf" "-X main.version=0.75.0 -X main.revision=c7bf2b8"
mkdir -p "$STAGE/usr/bin" "$STAGE/usr/share/fzf" "$STAGE/usr/share/licenses/fzf"
cp "$WORK/fzf" "$STAGE/usr/bin/fzf"
cp "$src/shell/key-bindings."* "$src/shell/completion."* "$STAGE/usr/share/fzf/" 2>/dev/null || true
cp "$src/LICENSE" "$STAGE/usr/share/licenses/fzf/"
ports_package 0.75.0 "Fuzzy finder for files, history and anything else (Ctrl-R, Ctrl-T)"
