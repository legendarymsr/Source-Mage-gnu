# The demo tools (bin/unterm, vterm-dump, vterm-ctrl) link with a bare -lvterm; slibtool does not add the
# build directory to the search path, so the link fails. Point the linker at .libs.
default_build_make $OPTS LDFLAGS="$LDFLAGS -L$SOURCE_DIRECTORY/.libs"
