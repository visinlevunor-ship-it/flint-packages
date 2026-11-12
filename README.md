# Flint Linux packages

The package repository for [Flint Linux](https://github.com/visinlevunor-ship-it/flint-linux),
and the recipes (`ports/`) that build it.

Flint's `pkg` reads it from
`https://raw.githubusercontent.com/visinlevunor-ship-it/flint-packages/main/x86_64`:

```sh
pkg install ripgrep zsh neovim
```

Every package is a **static** x86-64 build, so it runs on any Flint system with nothing else
installed. `x86_64/INDEX` lists each package with its size and SHA-256, and `x86_64/INDEX.sig`
is its Ed25519 signature. pkg installs nothing unless that signature matches a key in
`/etc/flint/keys/`.

## Packages

**Shells and terminal**

| Package | Version | |
|---|---|---|
| zsh | 5.9.2 | Z shell, with completion and a default `/etc/zsh/zshrc` |
| bash | 5.3 | GNU Bourne-Again shell |
| tmux | 3.8 | terminal multiplexer |
| fzf | 0.75.0 | fuzzy finder; shell key bindings in `/usr/share/fzf` |
| zoxide | 0.10.0 | smarter `cd` that learns where you go |

**Editors**

| Package | Version | |
|---|---|---|
| neovim | 0.12.4 | Vim-based editor, tree-sitter parsers built in |
| micro | 2.0.15 | modern terminal editor with mouse support |
| nano | 9.3 | simple editor, syntax highlighting on |

**Files and search**

| Package | Version | |
|---|---|---|
| ripgrep | 15.2.0 | `rg`: fast recursive search |
| fd | 10.5.2 | fast, friendly `find` |
| bat | 0.26.1 | `cat` with syntax highlighting |
| eza | 0.23.5 | modern `ls` |
| tree | 2.3.2 | directory trees |
| dust | 1.2.7 | what takes the disk space |
| ncdu | 1.22 | disk usage browser |
| sd | 1.0.0 | find and replace |
| jq | 1.8.2 | JSON processor |

**System**

| Package | Version | |
|---|---|---|
| htop | 3.5.3 | process viewer |
| btop | 1.4.7 | resource monitor |
| procs | 0.14.12 | modern `ps` |
| strace | 7.2 | trace system calls |
| fastfetch | 2.71.0 | system information, with the Flint logo |

**Network**

| Package | Version | |
|---|---|---|
| openssh | 10.5p1 | `ssh`, `scp`, `sftp`, `ssh-keygen`, `ssh-agent` |
| rsync | 3.5.2 | incremental file copying, locally and over ssh |
| curl | 8.23.0 | transfers over HTTP(S) and more |
| git | 2.55.0 | version control |
| ca-certificates | 20260816 | Mozilla's CA list, for curl and git |

**Archives and compression**

| Package | Version | |
|---|---|---|
| libarchive | 3.8.11 | `bsdtar` (tar, zip, 7z, iso…), `unzip`, `bsdcpio`, `bsdcat` |
| zstd | 1.5.7 | Zstandard |
| xz | 5.8.4 | XZ / LZMA |

**Development**

| Package | Version | |
|---|---|---|
| make | 4.4.1 | GNU make |
| lua | 5.4.9 | Lua interpreter and compiler |
| hyperfine | 2.0.0 | command-line benchmarking |
| tokei | 15.0.0 | count lines of code |

Kernels (`pkg kernels install zen|lts|upstream`) and the base system (`flint-update`) come
from this repository too, once they are published here.

## Building and publishing

The recipes are in [`ports/`](ports/README.md). To add or update a package:

```sh
ports/NAME/build.sh /tmp/NAME           # build it
pkg build /tmp/NAME x86_64/              # -> x86_64/NAME-VERSION.fpk
pkg index x86_64/                        # update INDEX
pkg sign x86_64/ ~/flint-keys/flint.key  # sign it (after every index)
git add -A && git commit && git push
```

Kernel packages need a built flint-linux checkout:

```sh
FLINT=../flint-linux ports/kernels/build.sh zen /tmp/zen && pkg build /tmp/zen x86_64/
```

Each program's license is installed with it, in `/usr/share/licenses/NAME/`.
