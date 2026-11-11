# Flint Linux packages

The package repository for [Flint Linux](https://github.com/visinlevunor-ship-it/flint-linux).
Flint's `pkg` reads it from
`https://raw.githubusercontent.com/visinlevunor-ship-it/flint-packages/main/x86_64`.

`x86_64/INDEX` lists every package with its size and SHA-256, and `x86_64/INDEX.sig` is its
Ed25519 signature. pkg installs nothing unless the signature matches a key in
`/etc/flint/keys/`.

| Package | Version | |
|---|---|---|
| fastfetch | 2.71.0 | system information next to a logo (MIT license, built from `ports/fastfetch`) |

## Adding or updating a package

```sh
pkg build SRC x86_64/
pkg index x86_64/
pkg sign x86_64/ ~/flint-keys/flint.key
git add -A && git commit && git push
```
