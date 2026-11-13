#!/usr/bin/env python3
"""Make Xorg one static binary with its drivers built in.

Xorg loads drivers as shared objects with dlopen, which a static binary cannot do. This
links the modesetting video driver, the shadow framebuffer module and the libinput input
driver (from xf86-input-libinput) into the server, and teaches the module loader to hand
them out from a table instead of searching the module directory.

usage: static-drivers.py XSERVER_SRC XF86_INPUT_LIBINPUT_SRC
"""
import os
import re
import shutil
import sys

xs, xil = sys.argv[1], sys.argv[2]


def edit(rel, old, new, count=1):
    p = os.path.join(xs, rel)
    s = open(p).read()
    if old not in s:
        sys.exit(f"{rel}: expected text not found:\n{old}")
    s = s.replace(old, new, count)
    open(p, "w").write(s)


# 1. The module loader: modules from a table, before looking for files.
edit("hw/xfree86/loader/loadmod.c",
     "ModuleDescPtr\nLoadModule(const char *module,",
     """#ifdef FLINT_STATIC_DRIVERS
/* Flint: drivers linked into the server (see ports/xorg/static-drivers.py). */
extern XF86ModuleData modesettingModuleData;
extern XF86ModuleData shadowModuleData;
extern XF86ModuleData libinputModuleData;

static XF86ModuleData *
FlintStaticModule(const char *name)
{
    static const struct {
        const char *name;
        XF86ModuleData *data;
    } table[] = {
        { "modesetting", &modesettingModuleData },
        { "shadow", &shadowModuleData },
        { "libinput", &libinputModuleData },
    };
    for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
        if (name && !strcmp(name, table[i].name))
            return table[i].data;
    return NULL;
}
#endif

ModuleDescPtr
LoadModule(const char *module,""")
edit("hw/xfree86/loader/loadmod.c",
     """    pathlist = defaultPathList;
    if (!pathlist) {""",
     """#ifdef FLINT_STATIC_DRIVERS
    if ((initdata = FlintStaticModule(name))) {
        LogMessageVerb(X_INFO, 3, "Module \\"%s\\" is built into this server\\n", name);
        ret->handle = NULL;
        goto flint_static_module;
    }
#endif

    pathlist = defaultPathList;
    if (!pathlist) {""")
edit("hw/xfree86/loader/loadmod.c",
     """    initdata = LoaderSymbolFromModule(ret, p);
    if (initdata) {""",
     """    initdata = LoaderSymbolFromModule(ret, p);
#ifdef FLINT_STATIC_DRIVERS
 flint_static_module:
#endif
    if (initdata) {""")
# a built-in module has no handle to close
p = os.path.join(xs, "hw/xfree86/loader/loader.c")
s = open(p).read()
s = re.sub(r"(void\nLoaderUnload\(const char \*name, void \*handle\)\n\{\n)",
           r"\1    if (!handle)\n        return;\n", s, count=1)
open(p, "w").write(s)

# 2. modesetting: a static library instead of a module.
p = os.path.join(xs, "hw/xfree86/drivers/modesetting/meson.build")
s = open(p).read()
start = s.index("shared_module(")
end = s.index("install_man(")
s = s[:start] + """flint_modesetting = static_library(
    'flint_modesetting_drv',
    modesetting_srcs,
    include_directories: [inc, xorg_inc],
    c_args: xorg_c_args,
    dependencies: [common_dep, udev_dep, libdrm_dep, gbm_dep],
)

""" + s[end:]
s = s[:s.index("test('modesetting symbol test'")] if "test('modesetting symbol test'" in s else s
open(p, "w").write(s)

# 3. xf86-input-libinput, built in the server tree.
drv = os.path.join(xs, "hw/xfree86/drivers/libinput")
os.makedirs(drv, exist_ok=True)
for f in os.listdir(os.path.join(xil, "src")):
    if f.endswith((".c", ".h")):
        shutil.copy(os.path.join(xil, "src", f), drv)
shutil.copy(os.path.join(xil, "include", "libinput-properties.h"), drv)
ver = re.search(r"AC_INIT\(\[xf86-input-libinput\],\s*\[([0-9.]+)\]", open(os.path.join(xil, "configure.ac")).read()).group(1)
major, minor, patch = (ver.split(".") + ["0", "0"])[:3]
open(os.path.join(drv, "config.h"), "w").write(f"""/* what xf86-input-libinput's configure would find with libinput {ver}+ */
#define HAVE_INPUTPROTO24 1
#define HAVE_LIBINPUT_AXIS_VALUE_V120 1
#define HAVE_LIBINPUT_CLICKFINGER_BUTTON_MAP 1
#define HAVE_LIBINPUT_CUSTOM_ACCEL 1
#define HAVE_LIBINPUT_PRESURE_RANGE 1
#define HAVE_LIBINPUT_SCROLL_BUTTON_LOCK 1
#define PACKAGE_VERSION "{ver}"
#define PACKAGE_VERSION_MAJOR {major}
#define PACKAGE_VERSION_MINOR {minor}
#define PACKAGE_VERSION_PATCHLEVEL {patch}
""")
# util-strings.c is a copy of libinput's, which is linked in already
os.remove(os.path.join(drv, "util-strings.c"))
srcs = sorted(f for f in os.listdir(drv) if f.endswith(".c"))
open(os.path.join(drv, "meson.build"), "w").write(f"""flint_libinput = static_library(
    'flint_libinput_drv',
    {srcs!r},
    include_directories: [inc, xorg_inc],
    # built like an external driver: its own config.h and the server's xorg-server.h
    c_args: xorg_c_args + ['-DHAVE_CONFIG_H', '-UHAVE_XORG_CONFIG_H', '-UHAVE_DIX_CONFIG_H'],
    dependencies: [common_dep, dependency('libinput')],
)
""")

# 4. Link them into Xorg; build no loadable modules.
edit("hw/xfree86/meson.build",
     "e = executable(\n    'Xorg',",
     """# Flint: the drivers are part of the executable
subdir('drivers/modesetting')
subdir('drivers/libinput')
flint_shadow = static_library(
    'flint_shadow',
    'dixmods/shmodule.c',
    include_directories: [inc, xorg_inc],
    c_args: xorg_c_args,
    dependencies: common_dep,
    link_whole: libxserver_miext_shadow,
)
xorg_link += [flint_modesetting, flint_libinput, flint_shadow]

e = executable(
    'Xorg',""")
p = os.path.join(xs, "hw/xfree86/meson.build")
s = open(p).read()
start = s.index("# subdirs for modules loadable by Xorg")
end = s.index("meson.add_install_script(")
s = s[:start] + "# (no loadable modules: Flint links its drivers into Xorg above)\n\n" + s[end:]
open(p, "w").write(s)
# the shared copy of the server, only for the modules' symbol tests, cannot be linked here
p = os.path.join(xs, "hw/xfree86/meson.build")
s = open(p).read()
start = s.index("# For symbol presence testing only")
end = s.index("\n", s.index("xorgserver_dep = declare_dependency(")) + 1
s = s[:start] + s[end:]
open(p, "w").write(s)

# 5. libmd through pkg-config: find_library does not search the build's -L paths
edit("meson.build", "md_dep = cc.find_library('md', required: false)",
     "md_dep = dependency('libmd', required: false)")
print("xorg-server patched for built-in drivers")
