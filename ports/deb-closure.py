#!/usr/bin/env python3
"""Pin a set of Ubuntu binary packages and everything they depend on.

    ports/deb-closure.py [--dist noble] [--exclude PKG,...] PKG... > ports/NAME/debs

Reads Ubuntu's package indexes (main and universe, the release and its -updates), follows
Depends and Pre-Depends (the first alternative of each), and prints one line per package:

    POOL_PATH SHA256 NAME VERSION

which deb_unpack_list (common.sh) fetches and checks. glibc itself and the packages that
only matter to a Debian system (dpkg, systemd, perl...) are left out: flint-glibc stands in
for glibc, and Flint has its own init and tools. --exclude leaves out more (data Flint
packages already ship).
"""
import argparse, lzma, re, sys, urllib.request

MIRROR = 'https://archive.ubuntu.com/ubuntu'

# glibc, and what a Debian system needs but a program does not
BASE_SKIP = {
    'libc6', 'libc-bin', 'libc6-dev', 'debconf', 'dpkg', 'perl-base', 'perl', 'coreutils',
    'bash', 'dash', 'sensible-utils', 'init-system-helpers', 'adduser', 'passwd', 'login',
    'systemd', 'systemd-sysv', 'libpam-systemd', 'tzdata', 'ucf', 'lsb-base', 'lsb-release',
    'sysvinit-utils', 'procps', 'mount', 'util-linux', 'udev', 'dbus', 'dbus-bin',
    'dbus-daemon', 'dbus-system-bus-common', 'dbus-session-bus-common', 'dbus-user-session',
    'dbus-system-bus', 'default-dbus-session-bus', 'dbus-session-bus', 'dconf-service',
    'python3', 'install-info', 'gpgv', 'sed', 'grep', 'findutils', 'gzip', 'tar',
}


def indexes(dist):
    for suite in (dist, dist + '-updates'):
        for comp in ('main', 'universe'):
            url = f'{MIRROR}/dists/{suite}/{comp}/binary-amd64/Packages.xz'
            print(f'reading {url}', file=sys.stderr)
            yield lzma.decompress(urllib.request.urlopen(url).read()).decode()


def parse(text, pkgs, provides):
    for block in text.split('\n\n'):
        f, key = {}, None
        for line in block.split('\n'):
            if line.startswith(' ') and key:
                f[key] += '\n' + line
            elif ':' in line:
                key, v = line.split(':', 1)
                f[key] = v.strip()
        if 'Package' not in f:
            continue
        pkgs[f['Package']] = f  # -updates is read last and wins
        for p in f.get('Provides', '').split(','):
            p = p.strip().split(' ')[0]
            if p:
                provides.setdefault(p, f['Package'])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dist', default='noble')
    ap.add_argument('--exclude', default='')
    ap.add_argument('packages', nargs='+')
    a = ap.parse_args()
    skip = BASE_SKIP | {x for x in a.exclude.split(',') if x}
    pkgs, provides = {}, {}
    for text in indexes(a.dist):
        parse(text, pkgs, provides)

    def resolve(n):
        if n in pkgs:
            return n
        return provides.get(n)

    seen, stack = [], list(reversed(a.packages))
    while stack:
        n = stack.pop()
        if n in skip:
            continue
        pn = resolve(n)
        if pn is None:
            sys.exit(f'no package provides {n}')
        if pn in seen or pn in skip:
            continue
        seen.append(pn)
        f = pkgs[pn]
        for dep in (f.get('Pre-Depends', '') + ',' + f.get('Depends', '')).split(','):
            dep = dep.strip()
            if dep:
                # the first alternative that exists
                for alt in dep.split('|'):
                    name = re.split(r'[ (:]', alt.strip())[0]
                    if resolve(name) or name in skip:
                        stack.append(name)
                        break
    for pn in sorted(seen):
        f = pkgs[pn]
        print(f"{f['Filename'][len('pool/'):]} {f['SHA256']} {pn} {f['Version']}")


main()
