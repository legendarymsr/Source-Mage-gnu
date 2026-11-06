cd "$SOURCE_DIRECTORY/$(cat "$SOURCE_DIRECTORY/.wl_arch")" &&
# The driver's debug macros expand to empty if-bodies; a kernel configured with
# CONFIG_WERROR=y would turn that harmless warning into a build failure.
make KVER="$(get_kernel_version)" KCFLAGS="-Wno-error"
