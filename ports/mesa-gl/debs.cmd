# everything gtk3-runtime ships is left out:
G=$(cut -d' ' -f3 ports/gtk3-runtime/debs | sort -u | tr '\n' ',' | sed 's/,$//')
ports/deb-closure.py --exclude "$G" libglx-mesa0 libgl1 libglx0 libopengl0 libegl1 libegl-mesa0 libgbm1 libgles2 mesa-vulkan-drivers mesa-libgallium libgl1-mesa-dri > ports/mesa-gl/debs
