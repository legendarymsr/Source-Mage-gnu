# rofi 1.7.4 declares `int yyparse();` while its generated parser has `int yyparse(void)`: a hard error
# under the C23 default of GCC 15. Build as gnu17.
CFLAGS="$CFLAGS -std=gnu17" &&
OPTS="${ROFI_OPTS} ${OPTS}" &&

default_build
