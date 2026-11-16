# everything gtk3-runtime and mesa-gl ship is left out, and Debian's X plumbing:
G=$( (cut -d' ' -f3 ports/gtk3-runtime/debs; cut -d' ' -f3 ports/mesa-gl/debs) | sort -u | tr '\n' ',' | sed 's/,$//')
ports/deb-closure.py --exclude "$G,xkb-data,x11-xkb-utils,keyboard-configuration,console-setup,console-setup-linux,xfonts-base,xfonts-utils,xfonts-encodings,x11-common,xserver-common" xserver-xorg-core xserver-xorg-input-libinput > ports/xorg-gl/debs
