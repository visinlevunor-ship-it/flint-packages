#!/bin/sh
# JetBrains Mono, the font Flint's terminal and bar use (the TrueType files from the
# project's repository at the v2.304 release). Usage: ports/fonts-jetbrains-mono/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init fonts-jetbrains-mono "${1:?usage: build.sh OUTDIR}"
src="$WORK/src/jbm"
# a shallow clone of the tag (the repository is big); the commit is checked
git -c advice.detachedHead=false clone -q --depth 1 --filter=blob:none --sparse --branch v2.304 \
    https://github.com/JetBrains/JetBrainsMono.git "$src" >>"$LOG" 2>&1 || die "cannot clone JetBrainsMono"
(cd "$src" && git sparse-checkout set fonts/ttf >>"$LOG" 2>&1)  # cone mode keeps the top-level files (OFL.txt) || die "sparse checkout failed"
[ "$(git -C "$src" rev-parse HEAD)" = "cd5227bd1f61dff3bbd6c814ceaf7ffd95e947d9" ] || die "v2.304 is not the expected commit"
mkdir -p "$STAGE/usr/share/fonts/jetbrains-mono" "$STAGE/usr/share/licenses/fonts-jetbrains-mono"
# the static weights (the variable fonts would duplicate them)
for w in Regular Bold Italic BoldItalic Medium; do
    cp "$src/fonts/ttf/JetBrainsMono-$w.ttf" "$STAGE/usr/share/fonts/jetbrains-mono/"
done
cp "$src/OFL.txt" "$STAGE/usr/share/licenses/fonts-jetbrains-mono/"
ports_package 2.304 "JetBrains Mono, a monospaced font for code and terminals"
