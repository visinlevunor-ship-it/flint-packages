#!/bin/sh
# zsh, the Z shell (static; its modules are built in). Usage: ports/zsh/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init zsh "${1:?usage: build.sh OUTDIR}"
lib_ncurses
src=$(unpack "$(fetch main/z/zsh/zsh_5.9.2.orig.tar.xz bc6737138e68aba0647b4f776a8e2785c750fb545af6e6a7d6d554e72d1b4c37)")
say "zsh"
(cd "$src" && { [ -x configure ] || ./Util/preconfig >>"$LOG" 2>&1; } && ./configure $HOSTFLAGS --prefix=/usr --bindir=/bin \
    --enable-etcdir=/etc/zsh --disable-dynamic --disable-gdbm --disable-pcre --disable-cap --with-tcsetpgrp \
    --enable-multibyte --with-term-lib=ncursesw >>"$LOG" 2>&1 \
    && make -j"$JOBS" >>"$LOG" 2>&1 && make install.bin install.fns DESTDIR="$STAGE" >>"$LOG" 2>&1)
rm -f "$STAGE/bin/zsh-"*
mkdir -p "$STAGE/etc/zsh"
cat > "$STAGE/etc/zsh/zshrc" <<'RC'
# Flint's default zsh settings (yours go in ~/.zshrc)
autoload -Uz compinit && compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump"
HISTFILE=~/.zsh_history HISTSIZE=10000 SAVEHIST=10000
setopt share_history hist_ignore_dups
bindkey -e
PROMPT='%B%F{yellow}%n@%m%f%b:%F{blue}%~%f%# '
RC
mkdir -p "$STAGE/usr/share/licenses/zsh" && cp "$src/LICENCE" "$STAGE/usr/share/licenses/zsh/"
ports_package 5.9.2 "Z shell: interactive shell with powerful completion" etc/zsh/zshrc
