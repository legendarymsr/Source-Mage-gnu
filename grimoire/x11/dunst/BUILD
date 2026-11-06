# dunst 1.11 builds `dunstify` against libnotify, but its code reads NotifyNotification->priv, which libnotify 0.8
# made private (compile error). The daemon and dunstctl do not need dunstify, so build only those.
make PREFIX="${INSTALL_ROOT}/usr" ${OPTS} dunst dunstctl doc service
