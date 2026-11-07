#!/usr/bin/env bash
# =============================================================================
# Source Mage GNU/Linux Install Script — sorcery, UEFI x86_64, ext4
# Same shape as gentoo/ exherbo/ kiss/ install.sh: partition -> unpack the
# base-system tarball -> fstab -> chroot -> sync grimoire & cast. Source-based:
# the kernel, Xorg and the desktop are COMPILED — budget hours. Run from any
# Linux live env as root (in the VM: the Gentoo minimal ISO, DISK=/dev/vda).
#
#   ./install.sh            auto — fresh install on an empty disk, RESUME an
#                           existing one (no wipe)
#   ./install.sh fresh      force a clean wipe + install
#   ./install.sh resume     re-enter an existing install and finish the casts
#
# Tunables (env):  DISK PROFILE INSTALL_DESKTOP HOSTNAME_ TIMEZONE USER_NAME
#                  SWAP_SIZE ESP_SIZE TARBALL_MIRRORS TARBALL_URL TARBALL_SHA512 VERIFY DRY_RUN ASSUME_YES CA_BUNDLE KB_LAYOUT
#   CA_BUNDLE=/path.pem extra CA file(s) trusted inside the chroot (TLS-inspecting proxy)
#   EXT4_OPTS="-O ^metadata_csum,^metadata_csum_seed,^orphan_file"  (default) keeps the root
#               filesystem mountable by the base tarball's old 3.4.51 kernel; set EXT4_OPTS=" "
#               for modern mkfs defaults once you run your own kernel
#   SKIP_CHROOT=1       stop after unpacking/configuring (no sorcery/casts); finish later with `resume`
#   JOBS=N              parallel compile jobs for sorcery and the kernel (default: number of CPUs)
#   UNATTENDED=1        no questions: stdin is /dev/null so every cast prompt takes its default, and
#                       the kernel is built from `make defconfig` (boots in QEMU/virtio; for real
#                       hardware prefer the interactive kernel menu). Pair with ROOT_PASSWORD=...
#   ROOT_PASSWORD=...   set root's password non-interactively (handed to the chroot in a 0600 file that is
#                       deleted afterwards, never written into the build script); USER_PASSWORD likewise
#                       (defaults to ROOT_PASSWORD)
#   SAVE_SPACE=1        do not keep sorcery's binary cache or downloaded sources (small disks)
#   SKIP_SPELLS="dillo" spells to leave out of the desktop/core lists
#   SKIP_EFI_CHECK=1    allow running from a non-UEFI host (installing to a disk image / loop device)
#   PROFILE=vm          virtio guest (default when DISK is /dev/vd*)
#   PROFILE=macbookair  i5-4250U / HD 5000 / CS4208 / Apple EFI (default else)
#   DRY_RUN=1           print every destructive command instead of running it
#
# Base image: the official Source Mage "test" basesystem tarball (0.63), which
# ships sorcery + a grimoire snapshot, so spell names are checked offline.
# Reference: https://sourcemage.org  ·  https://download.sourcemage.org/image/official/
# =============================================================================
set -euo pipefail

# ── Colours & helpers ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YEL='\033[0;33m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
warn()   { echo -e "${YEL}warn:${NC} $*" >&2; }
die()    { echo -e "${RED}error:${NC} $*" >&2; exit 1; }
DRY_RUN="${DRY_RUN:-0}"
run()    { if [[ "$DRY_RUN" == 1 ]]; then echo "[dry-run] $*"; else "$@"; fi; }
is_mounted() { mountpoint -q "$1" 2>/dev/null || grep -q " $1 " /proc/mounts 2>/dev/null; }
ask() { # ask VAR "prompt" default — env wins, else 10s prompt, else default
  local var="$1" msg="$2" def="$3" ans=""
  [[ -n "${!var:-}" ]] && return 0
  if [[ "${ASSUME_YES:-0}" == 1 || ! -t 0 ]]; then printf -v "$var" '%s' "$def"; return 0; fi
  echo -e "${CYAN}${msg} (10s, default: ${def})${NC}"; read -t 10 -r ans || true; echo
  printf -v "$var" '%s' "${ans:-$def}"
}

# ── Configuration ─────────────────────────────────────────────────────────────
# Never guess the disk to wipe without a person at the keyboard: unattended runs must name it.
if [[ -z "${DISK:-}" && ( "${ASSUME_YES:-0}" == 1 || ! -t 0 ) && "${DRY_RUN:-0}" != 1 ]]; then
  die "DISK is not set — refusing to pick a disk to wipe on an unattended run (e.g. DISK=/dev/vda)"
fi
ask DISK "Target disk to WIPE?" "/dev/vda"
if [[ -z "${PROFILE:-}" ]]; then case "$DISK" in /dev/vd*) PROFILE=vm ;; *) PROFILE=macbookair ;; esac; fi
case "$PROFILE" in vm|macbookair) ;; *) die "PROFILE must be vm or macbookair" ;; esac
ask INSTALL_DESKTOP "Install the bspwm desktop + rice (Xorg, bspwm, st, dillo, neovim — a LONG compile)? [yes/no]" "no"
case "${INSTALL_DESKTOP,,}" in y|yes|true) INSTALL_DESKTOP=true ;; *) INSTALL_DESKTOP=false ;; esac
HOSTNAME_="${HOSTNAME_:-sourcemage}"
TIMEZONE="${TIMEZONE:-America/New_York}"
USER_NAME="${USER_NAME:-}"                 # optional unprivileged user (you get a password prompt)
KB_LAYOUT="${KB_LAYOUT:-se}"           # setxkbmap layout in the bspwm rice (legenddots uses se)
SWAP_SIZE="${SWAP_SIZE:-4G}"; ESP_SIZE="${ESP_SIZE:-512M}"
VERIFY="${VERIFY:-true}"
CA_BUNDLE="${CA_BUNDLE:-}"
UNATTENDED="${UNATTENDED:-0}"; ROOT_PASSWORD="${ROOT_PASSWORD:-}"; USER_PASSWORD="${USER_PASSWORD:-$ROOT_PASSWORD}"; SAVE_SPACE="${SAVE_SPACE:-0}"
SKIP_EFI_CHECK="${SKIP_EFI_CHECK:-0}"
SKIP_SPELLS="${SKIP_SPELLS:-}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 1)}"
EXT4_OPTS="${EXT4_OPTS--O ^metadata_csum,^metadata_csum_seed,^orphan_file}"
SKIP_CHROOT="${SKIP_CHROOT:-0}"
# Base tarball: tried in order over https only (download.sourcemage.org itself only redirects to plain http).
#   1. ftp.accum.se  — Academic Computer Club, Umeå, Sweden (on sourcemage.org's mirror list)
#   2. mirror.sobukus.de — Germany (on sourcemage.org's mirror list; download.sourcemage.org's redirect target)
#   3. ftp.icm.edu.pl — ICM, Warsaw, Poland
# Each was checked to serve this exact file with the pinned sha512, which comes from a copy whose .sig verified against
# Source Mage developer key 4746AECF3E0B39BEF7C212ED478240C4FA5A74CE (shipped in sorcery-pubkeys), so no mirror can
# swap the tarball. A download failure or mismatch falls through to the next mirror. TARBALL_MIRRORS="url ..." replaces
# the list; TARBALL_URL=... uses just that URL (without TARBALL_SHA512 it falls back to the published .sha512).
TARBALL_PATH=image/official/test/smgl-test-0.63-20251212_1200-basesystem-x86_64.tar.xz
read -ra MIRRORS <<< "${TARBALL_MIRRORS:-https://ftp.accum.se/mirror/sourcemage.org https://mirror.sobukus.de/files/sourcemage https://ftp.icm.edu.pl/pub/Linux/dist/sourcemage}"
if [[ -n "${TARBALL_URL:-}" ]]; then URLS=("$TARBALL_URL")
else
  URLS=(); for m in "${MIRRORS[@]}"; do URLS+=("${m%/}/$TARBALL_PATH"); done
  TARBALL_SHA512="${TARBALL_SHA512:-579b164e393f0bb4ea2541d5818eaf75208e523fd954386b195bf0eb02cdc77c1bd486208ff707a3b05758d6e526e639870aaf6fd71405907b2b01ae2a8934b6}"
fi
TARBALL_SHA512="${TARBALL_SHA512:-}"
CURL=(curl -fL --proto "=https" --proto-redir "=https" --retry 3)    # https only, also after redirects
MNT=/mnt/sourcemage
SELF_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
TB="${URLS[0]##*/}"

# Spell names below were checked against the grimoire inside the base tarball
# (codex "test", 2025-12-12). The chroot phase re-checks them and skips (with a
# warning) any that no longer exist.
# elfutils: the linux spell only depends on it when the kernel config (not restored yet at dependency time) has
# UNWINDER_ORC, so it is never pulled in, and objtool then fails on a missing gelf.h. Cast it first.
SPELLS_CORE=(elfutils linux grub2 efibootmgr dhcpcd openssh sudo curl git)   # curl (with TLS) then git: git sources (dzen2) and nvim plugins need https
SPELLS_VM=()
SPELLS_MAC=(linux-firmware microcode_ctl alsa-utils broadcom-wl wpa_supplicant)   # broadcom-wl: local grimoire, see grimoire/
# bspwm rice, same stack as legenddots/bspwm (the grimoire has dzen2, not lemonbar; Dillo instead of surf) + neovim + fastfetch.
# xf86-input-evdev instead of -libinput: libinput 1.32 demands Lua >= 5.4 (the grimoire's default lua is 5.1).
# The libx*/xcb-util-cursor/libnotify entries are optional dependencies that unattended "no" answers would
# skip, but xsetroot, rofi and dunst cannot build without them: they are cast first (see PRE below).
SPELLS_DESKTOP=(xserver xinit xf86-input-evdev mesa dejavu-ttf ttf-jetbrains-mono
                libxcursor xcb-util-cursor libxscrnsaver libxinerama libnotify
                xsetroot setxkbmap bspwm sxhkd dzen2 picom rofi dunst slock st
                libjpeg-turbo giflib libwebp dillo fastfetch
                luajit neovim git xclip xauth)   # luajit before neovim: lazy.nvim needs a LuaJIT neovim (see CAST loop)
[[ $PROFILE == macbookair ]] && SPELLS_DESKTOP+=(xf86-video-intel)

# Unattended kernel: for the VM profile use kernel/vm.config (defconfig + EFI framebuffer console, Bochs/virtio
# GPU, PS/2 input; plain defconfig has NO framebuffer console, so a GUI window stays black). Other profiles
# get plain defconfig; for real hardware use the interactive kernel menu instead.
KMAKEMODE=defconfig; KRESTORE=""
if [[ $PROFILE == vm && -f "$SELF_DIR/kernel/vm.config" ]]; then KMAKEMODE=oldconfig; KRESTORE=/etc/sorcery/local/kernel.config; fi

# Mesa's default answers (first choice of every list) are Wayland / ARM / Freedreno / no GLX: unusable
# on x86 Xorg, and without EGL headers libepoxy (picom) cannot build. Seed an X11 build with GLX + EGL.
if [[ $PROFILE == macbookair ]]; then MESA_HW="Intel"; MESA_GALLIUM="crocus softpipe"   # HD 5000 = Haswell = crocus
else MESA_HW="VMware"; MESA_GALLIUM="softpipe virgl"; fi                                  # virtio-gpu = virgl

# ── Pre-flight ────────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" != 1 ]]; then
  [[ $EUID -eq 0 ]] || die "run as root"
  [[ -b "$DISK" ]]  || die "$DISK is not a block device"
  [[ -d /sys/firmware/efi || "$SKIP_EFI_CHECK" == 1 ]] || die "not booted in UEFI mode (this installer is UEFI-only; SKIP_EFI_CHECK=1 for disk images)"
fi
for t in sgdisk mkfs.fat mkfs.ext4 curl tar blkid partprobe sha512sum xz; do
  command -v "$t" >/dev/null || { [[ "$DRY_RUN" == 1 ]] && warn "missing tool: $t" || die "missing tool: $t"; }
done
[[ $(uname -m) == x86_64 ]] || die "x86_64 only"

# Partition node names differ for nvme/mmc (p1) vs sata/virtio (1).
case "$DISK" in *[0-9]) P="${DISK}p" ;; *) P="${DISK}" ;; esac
EFI="${P}1"; SWAP="${P}2"; ROOT="${P}3"

header "Hardware ($PROFILE)"
echo "  CPU : $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | xargs)"
echo "  RAM : $(awk '/MemTotal/ {printf "%.1f GiB", $2/1048576}' /proc/meminfo)"
echo "  Disk: $DISK  ->  ESP $EFI ($ESP_SIZE) · swap $SWAP ($SWAP_SIZE) · root $ROOT (rest)"

# ── Existing install? Then resume, don't wipe. ────────────────────────────────
is_existing() {
  [[ "$DRY_RUN" == 1 ]] && return 1
  mkdir -p "$MNT"
  if is_mounted "$MNT"; then [[ -d "$MNT/var/lib/sorcery" ]]; return; fi
  if mount "$ROOT" "$MNT" 2>/dev/null; then
    [[ -d "$MNT/var/lib/sorcery" ]] && return 0
    umount "$MNT" 2>/dev/null || true
  fi
  return 1
}
ARG="${1:-}"
case "$ARG" in
  fresh)  MODE=fresh ;;
  resume) MODE=resume ;;
  "")     if is_existing; then MODE=resume; else MODE=fresh; fi ;;
  *)      die "unknown mode '$ARG' (use: fresh | resume)" ;;
esac

write() { # write <path-in-target>; content on stdin
  if [[ "$DRY_RUN" == 1 ]]; then echo "[dry-run] write $MNT$1:"; sed 's/^/    /'
  else mkdir -p "$(dirname "$MNT$1")"; cat > "$MNT$1"; fi
}

# ── Fresh install: wipe, partition, unpack the base system ────────────────────
do_fresh() {
  echo -e "${YEL}About to ERASE ${DISK} and install Source Mage. Ctrl-C now to abort.${NC}"
  [[ "$DRY_RUN" == 1 || "${ASSUME_YES:-0}" == 1 ]] || sleep 5

  header "Partitioning ${DISK}"
  run swapoff "$SWAP" 2>/dev/null || true     # only our own swap partition, never the live system's
  run umount -R "$MNT" 2>/dev/null || true
  run sgdisk --zap-all "$DISK"
  run sgdisk --new=1:0:+"$ESP_SIZE"  --typecode=1:ef00 --change-name=1:EFI  "$DISK"
  run sgdisk --new=2:0:+"$SWAP_SIZE" --typecode=2:8200 --change-name=2:swap "$DISK"
  run sgdisk --new=3:0:0             --typecode=3:8300 --change-name=3:root "$DISK"
  run partprobe "$DISK"; [[ "$DRY_RUN" == 1 ]] || { udevadm settle 2>/dev/null || sleep 2; }

  header "Filesystems"
  run mkfs.fat -F32 "$EFI"
  run mkswap "$SWAP"; run swapon "$SWAP" || warn "could not swapon $SWAP (fine for a disk image)"
  # shellcheck disable=SC2086  # EXT4_OPTS is intentionally word-split
  run mkfs.ext4 -F $EXT4_OPTS "$ROOT"

  header "Mounting at ${MNT}"
  run mkdir -p "$MNT"
  run mount "$ROOT" "$MNT"
  run mkdir -p "$MNT/boot/efi"
  run mount "$EFI" "$MNT/boot/efi"

  header "Downloading base system ${TB}"
  if [[ "$DRY_RUN" == 1 ]]; then
    for u in "${URLS[@]}"; do echo "[dry-run] ${CURL[*]} -# -o $MNT/$TB $u  (+ sha512 verify; next mirror on failure)"; done
  else
    local u ok=0 sum
    for u in "${URLS[@]}"; do
      echo "  from $u"
      rm -f "${MNT:?}/${TB:?}"
      "${CURL[@]}" -# -o "$MNT/$TB" "$u" || { warn "download failed: $u"; continue; }
      [[ "$VERIFY" == "true" ]] || { ok=1; break; }
      sum="$TARBALL_SHA512"
      if [[ -z "$sum" ]]; then
        warn "no pinned TARBALL_SHA512 for a custom TARBALL_URL — using the mirror's own .sha512 (catches corruption, not tampering)"
        sum=$("${CURL[@]}" -s "${u}.sha512" | awk 'NR==1 {print $1}') || true
        [[ -n "$sum" ]] || { warn "no .sha512 for $u — set TARBALL_SHA512=... or VERIFY=false"; continue; }
      fi
      if echo "$sum  $MNT/$TB" | sha512sum -c --quiet -; then echo "  sha512 OK"; ok=1; break; fi
      warn "sha512 mismatch from $u — trying the next mirror"
    done
    ((ok)) || { rm -f "${MNT:?}/${TB:?}"; die "could not get a verified base tarball from: ${URLS[*]}"; }
  fi
  header "Unpacking into ${MNT}"
  run tar xpf "$MNT/$TB" -C "$MNT" --xattrs-include='*.*' --numeric-owner
  run rm -f "${MNT:?}/${TB:?}"

  header "Writing /etc/fstab, hostname, timezone"
  local ur ue us
  ur=$(blkid -s UUID -o value "$ROOT" 2>/dev/null || echo ROOT-UUID)
  ue=$(blkid -s UUID -o value "$EFI"  2>/dev/null || echo ESP-UUID)
  us=$(blkid -s UUID -o value "$SWAP" 2>/dev/null || echo SWAP-UUID)
  write /etc/fstab <<FSTAB_END
# <device>        <mount>   <type>  <opts>          <dump> <pass>
UUID=$ur  /          ext4    noatime         0 1
UUID=$ue  /boot/efi  vfat    umask=0077      0 2
UUID=$us  none       swap    sw              0 0

proc            /proc     proc    defaults        0 0
devpts          /dev/pts  devpts  defaults        0 0
tmpfs           /dev/shm  tmpfs   size=128m       0 0
FSTAB_END
  echo "$HOSTNAME_" | write /etc/hostname
  run ln -sf "/usr/share/zoneinfo/$TIMEZONE" "$MNT/etc/localtime"
}

# ── Profile-specific config ───────────────────────────────────────────────────
write_profile_config() {
  # No initramfs, so the kernel cannot resolve root=UUID=...: make grub-mkconfig use the device name.
  # devtmpfs.mount=1: Source Mage's simpleinit keeps /dev/initctl in /dev, so the kernel must
  # auto-mount devtmpfs (init otherwise stalls after udev coldplug). GFXPAYLOAD=keep keeps the
  # UEFI framebuffer so the screen is not blank.
  write /etc/default/grub <<GRUB_END
GRUB_DISTRIBUTOR="SourceMage"
GRUB_TIMEOUT=3
GRUB_DISABLE_LINUX_UUID=true
GRUB_CMDLINE_LINUX_DEFAULT="devtmpfs.mount=1"
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_END
  if [[ $PROFILE == vm ]]; then
    # /etc/inittab only has gettys on tty1-6; add a serial one (harmless on a GUI display)
    if [[ "$DRY_RUN" == 1 ]]; then
      echo "[dry-run] add 'ttyS0:linux:/sbin/agetty -L ttyS0 115200 vt100' to $MNT/etc/inittab"
    elif ! grep -q '^ttyS0:' "$MNT/etc/inittab"; then
      sed -i '/^tty6:/a ttyS0:linux:/sbin/agetty -L ttyS0 115200 vt100' "$MNT/etc/inittab"
    fi
    # The base system ships /etc/network/interfaces with only lo (eth0 is a commented static example), so the
    # "network" service never brings the virtio NIC up and the guest has no DHCP lease. The kernel names it eth0.
    write /etc/network/interfaces <<NET_END
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
NET_END
  fi
  if [[ $PROFILE == macbookair ]]; then
    write /etc/modprobe.d/sound.conf <<SND_END
# CS4208 on MacBook Air 6,x; if the speakers stay silent try model=auto
options snd-hda-intel model=mba6
SND_END
    write /etc/modules-load.d/apple.conf <<MOD_END
applesmc
MOD_END
  fi
}

# ── Local grimoire (spells that are not in the official one, e.g. broadcom-wl) ─
install_local_grimoire() {
  [[ -d "$SELF_DIR/grimoire" ]] || return 0
  header "Installing local grimoire (dzen2 over https, broadcom-wl)"
  run mkdir -p "$MNT/var/lib/sorcery/codex/local" "$MNT/etc/sorcery/local"
  run cp -a "$SELF_DIR/grimoire/." "$MNT/var/lib/sorcery/codex/local/"
  # spells source helper files (FUNCTIONS, MESON_DEPENDS, ...) from their own grimoire's root, so the local
  # grimoire needs the official grimoire's top-level files: symlink them (they stay current across scribe updates)
  if [[ "$DRY_RUN" == 1 ]]; then echo "[dry-run] symlink the official grimoire's top-level files into codex/local"
  else
    local off; off=$(find "$MNT/var/lib/sorcery/codex" -mindepth 1 -maxdepth 1 -type d ! -name local | head -1)
    if [[ -n "$off" ]]; then
      for f in "$off"/*; do
        [[ -f "$f" && "$f" != *.index && "${f##*/}" != GRIMOIRE ]] || continue
        ln -sfn "../$(basename "$off")/$(basename "$f")" "$MNT/var/lib/sorcery/codex/local/$(basename "$f")"
      done
    fi
    # Its own metadata, marked local: a symlinked GRIMOIRE would carry the official FROM_URL, and `scribe update`
    # would then download the official grimoire over this one (losing every local fix).
    rm -f "$MNT/var/lib/sorcery/codex/local/GRIMOIRE"
    echo 'CODEX_IS_LOCAL=yes' > "$MNT/var/lib/sorcery/codex/local/GRIMOIRE"
  fi
  if [[ "$DRY_RUN" == 1 ]]; then
    echo "[dry-run] append GRIMOIRE_DIR[1]=/var/lib/sorcery/codex/local to $MNT/etc/sorcery/local/grimoire"
  elif ! grep -qs 'codex/local' "$MNT/etc/sorcery/local/grimoire"; then
    # local FIRST: its spells (dzen2 over https, broadcom-wl) override/extend the official grimoire
    local GF="$MNT/etc/sorcery/local/grimoire"
    { echo 'GRIMOIRE_DIR[0]=/var/lib/sorcery/codex/local'
      sed -E 's/GRIMOIRE_DIR\[[0-9]+\]/GRIMOIRE_DIR[1]/' "$GF"; } > "$GF.new" && mv "$GF.new" "$GF"
  fi
}

# ── Sorcery settings: parallel builds, unattended kernel answers, space saving ──
write_sorcery_config() {
  header "Configuring sorcery (JOBS=$JOBS${UNATTENDED:+, UNATTENDED=$UNATTENDED}${SAVE_SPACE:+, SAVE_SPACE=$SAVE_SPACE})"
  write /etc/sorcery/local/compile_config <<CC_END
MAKE_NJOBS="$JOBS"
CC_END
  if [[ "$UNATTENDED" == 1 && -n "$KRESTORE" ]]; then run install -D -m 0644 "$SELF_DIR/kernel/vm.config" "$MNT$KRESTORE"; fi
  if [[ "$SAVE_SPACE" == 1 ]]; then
    if [[ "$DRY_RUN" == 1 ]]; then echo '[dry-run] append ARCHIVE="off" CLEAN_SOURCE="on" to /etc/sorcery/local/config'
    else printf '%s\n' 'ARCHIVE="off"' 'CLEAN_SOURCE="on"' >> "$MNT/etc/sorcery/local/config"; fi
  fi
}

# ── bspwm rice + nvim config (files live in ./rice, deployed to /etc/skel and /root) ──
install_rice() {
  [[ -d "$SELF_DIR/rice" ]] || { warn "no rice/ directory next to install.sh — skipping the bspwm rice"; return 0; }
  header "Installing the bspwm rice + nvim config (layout: $KB_LAYOUT)"
  local home f
  for home in "$MNT/etc/skel" "$MNT/root"; do
    for f in bspwm/bspwmrc sxhkd/sxhkdrc dzen2/bar.sh picom/picom.conf rofi/config.rasi dunst/dunstrc nvim/init.lua fastfetch/config.jsonc dillo/fastfetch-html dillo/nvim-html dillo/www-server dillo/www-open; do
      case "$f" in
        */fastfetch-html|*/nvim-html|*/www-server|*/www-open) run install -D -m 0755 "$SELF_DIR/rice/$f" "$home/.config/$f" ;;
        */bspwmrc) # layout substitution
          if [[ "$DRY_RUN" == 1 ]]; then echo "[dry-run] install rice/$f -> $home/.config/$f (KB_LAYOUT=$KB_LAYOUT)"
          else install -D -m 0755 /dev/null "$home/.config/$f"; sed "s/@KB_LAYOUT@/$KB_LAYOUT/" "$SELF_DIR/rice/$f" > "$home/.config/$f"; fi ;;
        *.sh) run install -D -m 0755 "$SELF_DIR/rice/$f" "$home/.config/$f" ;;
        *)    run install -D -m 0644 "$SELF_DIR/rice/$f" "$home/.config/$f" ;;
      esac
    done
    run install -D -m 0644 "$SELF_DIR/rice/xinitrc" "$home/.xinitrc"
    run install -D -m 0644 "$SELF_DIR/rice/dillo/dillorc" "$home/.dillo/dillorc"
    run install -D -m 0644 "$SELF_DIR/rice/dillo/keysrc"  "$home/.dillo/keysrc"
  done
}

# ── Resume path: remount what a fresh install would have mounted ──────────────
do_resume() {
  header "Resuming existing install"
  is_mounted "$MNT" || run mount "$ROOT" "$MNT"
  is_mounted "$MNT/boot/efi" || { run mkdir -p "$MNT/boot/efi"; run mount "$EFI" "$MNT/boot/efi"; }
  run swapon "$SWAP" 2>/dev/null || true
}

if [[ $MODE == fresh ]]; then do_fresh; else do_resume; fi
write_profile_config
write_sorcery_config
install_local_grimoire
$INSTALL_DESKTOP && install_rice

if [[ "$SKIP_CHROOT" == 1 ]]; then
  header "SKIP_CHROOT=1 — base system unpacked and configured; skipping the sorcery/chroot phase"
  run umount -R "$MNT" || warn "could not unmount everything cleanly"
  run swapoff "$SWAP" 2>/dev/null || true
  echo -e "${GREEN}Base installed.${NC} Run ./install.sh resume to sync the grimoire, cast the kernel and bootloader."
  exit 0
fi

# ── The in-chroot phase, written out as a real script (no quoting soup) ───────
header "Preparing chroot"
for d in dev proc sys; do is_mounted "$MNT/$d" || run mount --rbind "/$d" "$MNT/$d"; done
run cp -L /etc/resolv.conf "$MNT/etc/resolv.conf"
[[ -n "$CA_BUNDLE" ]] && run install -D -m 0644 "$CA_BUNDLE" "$MNT/root/ca-bundle.pem"

SPELLS=("${SPELLS_CORE[@]}")
if [[ $PROFILE == macbookair ]]; then SPELLS+=("${SPELLS_MAC[@]}"); else SPELLS+=("${SPELLS_VM[@]}"); fi
$INSTALL_DESKTOP && SPELLS+=("${SPELLS_DESKTOP[@]}")
if [[ -n "$SKIP_SPELLS" ]]; then
  FILTERED=(); for s in "${SPELLS[@]}"; do [[ " $SKIP_SPELLS " == *" $s "* ]] || FILTERED+=("$s"); done
  SPELLS=("${FILTERED[@]}")
fi

write /root/sm-chroot.sh <<CHROOT_END
#!/bin/bash
set -uo pipefail
export HOME=/root TERM="${TERM:-linux}"
# The live ISO's PATH (e.g. Gentoo's) has no /bin, /sbin or /usr/sbin: Source Mage's tools live there.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
FAILED=()
if [[ -n "$CA_BUNDLE" ]]; then
  export SSL_CERT_FILE=/root/ca-bundle.pem CURL_CA_BUNDLE=/root/ca-bundle.pem
  echo "ca_certificate=/root/ca-bundle.pem" > /root/.wgetrc
  printf '[http]\n\tsslCAInfo = /root/ca-bundle.pem\n' > /root/.gitconfig
fi
echo "── Syncing grimoire (scribe update)"
scribe update || echo "warn: scribe update failed — using the grimoire snapshot from the tarball"
command -v cast >/dev/null || { echo "error: sorcery (cast) not found in the chroot"; exit 2; }
# make the local grimoire's spells (dzen2, broadcom-wl) known to sorcery
if [[ -d /var/lib/sorcery/codex/local ]]; then scribe reindex local >/dev/null 2>&1; scribe reindex-version local >/dev/null 2>&1; fi

if [[ "$UNATTENDED" == 1 ]]; then
  # The base tarball saves answers for an old 3.4.51 kernel. Replace them with a fully non-interactive
  # build of the NEWEST kernel series the (just refreshed) grimoire offers: \`make defconfig\` builds in
  # virtio, EXT4, the EFI stub and DEVTMPFS_MOUNT; no bootloader update (GRUB is installed below).
  KD=\$(find /var/lib/sorcery/codex -mindepth 4 -maxdepth 4 -path '*/kernels/linux/latest.defaults' | head -1)
  KMAJ=\$(grep -oE '^LATEST_[0-9]+' "\$KD" 2>/dev/null | sort -t_ -k2 -n | tail -1)
  if [[ -n "\$KMAJ" ]]; then
    echo "── Kernel series for the unattended build: \$KMAJ"
    mkdir -p /etc/sorcery/local/depends
    cat > /etc/sorcery/local/depends/linux.p <<LP_END
KERNEL_ARCH="x86_64"
KMODE="newktree"
KLINUX_RECONFIGURE="false"
BASE_KVER="\$KMAJ"
SELECTED_PATCHES="LATEST_maintenance_patches_\${KMAJ#LATEST_}"
EXTRA_MAKE_OPTIONS="-j$JOBS"
CONFIG_RESTORE="$KRESTORE"
MAKEMODE="$KMAKEMODE"
UPDATE_BL="n"
LP_END
  else
    echo "warn: no LATEST_<n> kernel found in latest.defaults — the linux cast may prompt or fail"
  fi
fi

# This installer is UEFI-only, but the grub2 spell's default answer is the BIOS build (i386-pc), whose
# grub-install has no x86_64-efi modules. Pre-seed the platform answer sorcery would otherwise ask for.
mkdir -p /etc/sorcery/local/depends
cat > /etc/sorcery/local/depends/grub2.p <<GP_END
GRUB2_OPTS="--disable-mm-debug --disable-efiemu"
GRUB2_PLATFORM="x86_64-efi"
GRUB2_RELEASE="stable"
GP_END
# neovim wants the LuaJIT 2.1 snapshot (lazy.nvim does not run on PUC Lua). The stock luajit would default to the
# stable 2.0.5 and then conflict with neovim's SNAPSHOT sub-dependency, so pre-select the branch (the local grimoire's
# luajit spell clones it from GitHub; repo.or.cz answers scripted clients with a bot check).
cat > /etc/sorcery/local/depends/luajit.p <<LJ_END
LUAJIT_BRANCH="snapshot"
LJ_END
# curl's SSL provider defaults to "none" (--without-ssl): no https for curl or (through it) git. Use openssl.
touch /etc/sorcery/local/depends/curl.p
if grep -q '^CURL_SSL=' /etc/sorcery/local/depends/curl.p; then sed -i 's/^CURL_SSL=.*/CURL_SSL="openssl"/' /etc/sorcery/local/depends/curl.p
else echo 'CURL_SSL="openssl"' >> /etc/sorcery/local/depends/curl.p; fi
if [[ "$INSTALL_DESKTOP" == true ]]; then
  cat > /etc/sorcery/local/depends/mesa.p <<MP_END
MESA_BRANCH="stable"
MESON_BUILD_TYPE="plain"
MESA_PLATFORMS="x11"
MESA_ARCH="x86"
MESA_HW="$MESA_HW"
MESA_GALLIUM_CHOICE="$MESA_GALLIUM"
MESA_GALLIUM="$MESA_GALLIUM"
MESA_GALLIUM_HUD="n"
MESA_RUSTICL="n"
MESA_EGL="y"
MESA_EGL_DEFAULT="auto"
MESA_VULKAN_CHOICE="none"
MESA_VULKAN="none"
MESA_VULKAN_LAYERS=""
MESA_SHADER_CACHE="n"
MESA_GLES1="n"
MESA_GLES23="y"
MESA_OPENGL="y"
MESA_GBM="y"
MESA_GLX_CHOICE="dri"
MESA_GLX="dri"
MESA_GLX_DIRECT="y"
MESA_GLX_READONLY="n"
MESA_GLVND="n"
MESA_SPIRV_DXIL="n"
MESA_TOOLS_CHOICE="none"
MESA_TOOLS="none"
MESA_TEFLON="n"
MESA_GPUVIS="n"
MESA_VIDEO_CODECS="none"
MESA_XMLCONFIG="n"
MESA_EXTERNAL_GBM="n"
MP_END
fi

# codex layout is <grimoire>/<section>/<spell>, i.e. 3 levels below /var/lib/sorcery/codex
have_spell() { find /var/lib/sorcery/codex -mindepth 3 -maxdepth 3 -type d -name "\$1" 2>/dev/null | grep -q .; }
WANT=(${SPELLS[*]})
# an already-installed spell that was built wrongly (BIOS-only grub2, EGL-less mesa) must be recompiled
needs_recast() {
  case "\$1" in
    grub2) [[ -d /usr/lib/grub/i386-pc && ! -d /usr/lib/grub/x86_64-efi ]] ;;
    mesa)  [[ ! -e /usr/include/EGL/egl.h ]] ;;
    neovim) command -v nvim >/dev/null && ! nvim --version 2>/dev/null | grep -qi luajit ;;   # lazy.nvim needs LuaJIT, not PUC Lua
    *)     return 1 ;;
  esac
}
# sorcery records installs as spell:date:installed:version; a resume must not recompile them
is_installed() { grep -q "^\$1:[^:]*:installed:" /var/state/sorcery/packages 2>/dev/null; }
CAST=(); for s in "\${WANT[@]}"; do
  if ! have_spell "\$s"; then echo "warn: spell '\$s' not in the grimoire — skipping"
  elif is_installed "\$s" && ! needs_recast "\$s"; then
    echo "already installed: \$s — skipping"
  else CAST+=("\$s"); fi
done

# Kernel first, bootloader second: a bootable system exists even if a later
# desktop cast fails. The linux spell opens a kernel config menu — see the
# README for the options this machine needs built IN (no initramfs).
echo "── Casting: \${CAST[*]}"
for s in elfutils linux grub2 efibootmgr curl git mesa libxcursor xcb-util-cursor libxscrnsaver libxinerama libnotify libjpeg-turbo giflib libwebp luajit; do
  COPT=()
  # an earlier BIOS build of grub2 (no EFI modules) must be recompiled, not skipped as "no work to do"
  needs_recast "\$s" && is_installed "\$s" && COPT=(-c)
  [[ " \${CAST[*]} " == *" \$s "* ]] && { cast "\${COPT[@]}" "\$s" || { echo "warn: cast \$s failed (re-run ./install.sh resume)"; FAILED+=("cast \$s"); }; }
done

echo "── Installing GRUB (UEFI, removable path — works on OVMF and Apple EFI)"
grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable || { echo "warn: grub-install --removable failed"; FAILED+=("grub-install"); }
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=SourceMage 2>/dev/null || true
grub-mkconfig -o /boot/grub/grub.cfg || { echo "warn: grub-mkconfig failed"; FAILED+=("grub-mkconfig"); }

REST=(); for s in "\${CAST[@]}"; do case "\$s" in elfutils|linux|grub2|efibootmgr|curl|git|mesa|libxcursor|xcb-util-cursor|libxscrnsaver|libxinerama|libnotify|libjpeg-turbo|giflib|libwebp|luajit|sudo) ;; *) REST+=("\$s") ;; esac; done
((\${#REST[@]})) && { cast "\${REST[@]}" || { echo "warn: some casts failed — re-run: ./install.sh resume"; FAILED+=("cast \${REST[*]}"); }; }
# sudo asks sorcery for its TEXT-EDITOR provider and gets neovim when neovim is in the same cast list; its build runs
# a hash check for neovim, so it must come after everything else (otherwise: "hash: neovim: not found")
for s in sudo; do
  [[ " \${CAST[*]} " == *" \$s "* ]] && { cast "\$s" || { echo "warn: cast \$s failed (re-run ./install.sh resume)"; FAILED+=("cast \$s"); }; }
done

echo "── Set the root password"
PWF=/root/.sm-passwords      # written by install.sh (mode 0600), removed after the chroot
if grep -q '^root:' "\$PWF" 2>/dev/null; then grep '^root:' "\$PWF" | chpasswd || FAILED+=("passwd root"); else passwd root || FAILED+=("passwd root"); fi
if [[ "$INSTALL_DESKTOP" == true ]] && command -v slock >/dev/null; then chmod u+s "\$(command -v slock)"; fi
# No logind here, so a normal user cannot open the DRM/VT devices: make Xorg setuid (it drops privileges after opening them)
if [[ "$INSTALL_DESKTOP" == true && -x /usr/bin/Xorg ]]; then chmod u+s /usr/bin/Xorg; fi
if [[ -n "$USER_NAME" ]]; then
  id "$USER_NAME" >/dev/null 2>&1 || useradd -m -G video,input,audio "$USER_NAME"
  # X needs /dev/dri (video), /dev/input (input); make sure an existing user has them too
  if [[ "$INSTALL_DESKTOP" == true ]]; then usermod -aG video,input,audio "$USER_NAME" 2>/dev/null || true; fi
  # users created before the rice was installed do not get /etc/skel: copy it in (never overwrite)
  if [[ "$INSTALL_DESKTOP" == true && ! -e "/home/$USER_NAME/.config/bspwm" ]]; then
    cp -rn /etc/skel/. "/home/$USER_NAME/" && chown -R "$USER_NAME:\$(id -gn "$USER_NAME")" "/home/$USER_NAME"
  fi
  echo "── Set the password for $USER_NAME"
  if grep -q '^$USER_NAME:' "\$PWF" 2>/dev/null; then grep '^$USER_NAME:' "\$PWF" | chpasswd || FAILED+=("passwd $USER_NAME"); else passwd "$USER_NAME" || FAILED+=("passwd $USER_NAME"); fi
fi
if ((\${#FAILED[@]})); then echo "FAILED STEPS: \${FAILED[*]}"; exit 1; fi
CHROOT_END
run chmod +x "$MNT/root/sm-chroot.sh"
# Passwords go to the chroot in a root-only file, never into sm-chroot.sh (which dry-run prints) or a command line.
if [[ "$DRY_RUN" == 1 ]]; then echo "[dry-run] write $MNT/root/.sm-passwords (0600, not shown)"
elif [[ -n "$ROOT_PASSWORD" || ( -n "$USER_NAME" && -n "$USER_PASSWORD" ) ]]; then
  ( umask 077
    { [[ -n "$ROOT_PASSWORD" ]] && printf 'root:%s\n' "$ROOT_PASSWORD"
      [[ -n "$USER_NAME" && -n "$USER_PASSWORD" ]] && printf '%s:%s\n' "$USER_NAME" "$USER_PASSWORD"
      true; } > "$MNT/root/.sm-passwords" )
fi

header "Entering chroot to configure & build (this compiles from source)"
CHROOT_RC=0
CHROOT_IN=/dev/stdin; [[ "$UNATTENDED" == 1 ]] && CHROOT_IN=/dev/null   # EOF on stdin = every prompt takes its default
run env -i HOME=/root TERM="${TERM:-linux}" PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    chroot "$MNT" /bin/bash /root/sm-chroot.sh < "$CHROOT_IN" || CHROOT_RC=$?
[[ -f "$MNT/root/.sm-passwords" ]] && { shred -u "$MNT/root/.sm-passwords" 2>/dev/null || rm -f "$MNT/root/.sm-passwords"; }
run rm -f "${MNT:?}/root/sm-chroot.sh" "${MNT:?}/root/ca-bundle.pem" "${MNT:?}/root/.wgetrc" "${MNT:?}/root/.gitconfig"

header "Cleaning up"
run umount -R "$MNT" || warn "could not unmount everything cleanly"
run swapoff "$SWAP" 2>/dev/null || true
if ((CHROOT_RC)); then
  warn "the chroot phase reported failures (exit $CHROOT_RC) — the system is NOT complete. Fix the errors above and re-run: ./install.sh resume"
  exit "$CHROOT_RC"
fi
echo -e "${GREEN}Done.${NC} Power off, detach the ISO, and boot the disk."
