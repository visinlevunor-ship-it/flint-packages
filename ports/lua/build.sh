#!/bin/sh
# Lua 5.4 (static). Usage: ports/lua/build.sh OUTDIR
. "$(dirname "$0")/../common.sh"
ports_init lua "${1:?usage: build.sh OUTDIR}"
src=$(unpack "$(fetch main/l/lua5.4/lua5.4_5.4.9.orig.tar.gz 2335b6c582a52654f94612bf10d2f4672805d05329aa6568b1d8cd9e5c6fb8e6)")
say "lua"
(cd "$src" && make -j"$JOBS" posix CC="$CC" AR="$AR rcu" RANLIB="$RANLIB" MYCFLAGS="-Os" MYLDFLAGS="-static" >>"$LOG" 2>&1)
mkdir -p "$STAGE/usr/bin" "$STAGE/usr/share/licenses/lua"
cp "$src/src/lua" "$src/src/luac" "$STAGE/usr/bin/"
ln -s lua "$STAGE/usr/bin/lua5.4"
sed -n '/Copyright/,/SOFTWARE\./p' "$src/src/lua.h" > "$STAGE/usr/share/licenses/lua/LICENSE"
ports_package 5.4.9 "Lua 5.4 scripting language (lua, luac)"
