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
#                  SWAP_SIZE ESP_SIZE TARBALL_URL VERIFY DRY_RUN ASSUME_YES
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
ask DISK "Target disk to WIPE?" "/dev/vda"
if [[ -z "${PROFILE:-}" ]]; then case "$DISK" in /dev/vd*) PROFILE=vm ;; *) PROFILE=macbookair ;; esac; fi
case "$PROFILE" in vm|macbookair) ;; *) die "PROFILE must be vm or macbookair" ;; esac
ask INSTALL_DESKTOP "Install the Xfce desktop (Xorg + Xfce + Firefox — a LONG compile)? [yes/no]" "no"
case "${INSTALL_DESKTOP,,}" in y|yes|true) INSTALL_DESKTOP=true ;; *) INSTALL_DESKTOP=false ;; esac
HOSTNAME_="${HOSTNAME_:-sourcemage}"
TIMEZONE="${TIMEZONE:-America/New_York}"
USER_NAME="${USER_NAME:-}"                 # optional unprivileged user (you get a password prompt)
SWAP_SIZE="${SWAP_SIZE:-4G}"; ESP_SIZE="${ESP_SIZE:-512M}"
VERIFY="${VERIFY:-true}"
TARBALL_URL="${TARBALL_URL:-https://download.sourcemage.org/image/official/test/smgl-test-0.63-20251212_1200-basesystem-x86_64.tar.xz}"
MNT=/mnt/sourcemage
TB="${TARBALL_URL##*/}"

# Spell names below were checked against the grimoire inside the base tarball
# (codex "test", 2025-12-12). The chroot phase re-checks them and skips (with a
# warning) any that no longer exist.
SPELLS_CORE=(linux grub2 efibootmgr dhcpcd openssh sudo)
SPELLS_VM=()
SPELLS_MAC=(linux-firmware microcode_ctl alsa-utils wpa_supplicant)
SPELLS_DESKTOP=(xorg-server xinit xf86-input-libinput mesa dejavu-ttf
                xfce4-session xfwm4 xfce4-panel xfce4-settings xfdesktop thunar
                xfce4-terminal xfce4-appfinder firefox)
[[ $PROFILE == macbookair ]] && SPELLS_DESKTOP+=(xf86-video-intel)

# ── Pre-flight ────────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" != 1 ]]; then
  [[ $EUID -eq 0 ]] || die "run as root"
  [[ -b "$DISK" ]]  || die "$DISK is not a block device"
  [[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode (this installer is UEFI-only)"
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
  run swapoff -a || true
  run umount -R "$MNT" 2>/dev/null || true
  run sgdisk --zap-all "$DISK"
  run sgdisk --new=1:0:+"$ESP_SIZE"  --typecode=1:ef00 --change-name=1:EFI  "$DISK"
  run sgdisk --new=2:0:+"$SWAP_SIZE" --typecode=2:8200 --change-name=2:swap "$DISK"
  run sgdisk --new=3:0:0             --typecode=3:8300 --change-name=3:root "$DISK"
  run partprobe "$DISK"; [[ "$DRY_RUN" == 1 ]] || { udevadm settle 2>/dev/null || sleep 2; }

  header "Filesystems"
  run mkfs.fat -F32 "$EFI"
  run mkswap "$SWAP"; run swapon "$SWAP"
  run mkfs.ext4 -F "$ROOT"

  header "Mounting at ${MNT}"
  run mkdir -p "$MNT"
  run mount "$ROOT" "$MNT"
  run mkdir -p "$MNT/boot/efi"
  run mount "$EFI" "$MNT/boot/efi"

  header "Downloading base system ${TB}"
  if [[ "$DRY_RUN" == 1 ]]; then
    echo "[dry-run] curl -fL# -O $TARBALL_URL  (+ .sha512 verify)"
  else
    ( cd "$MNT" && curl -fL# -O "$TARBALL_URL" )
    if [[ "$VERIFY" == "true" ]]; then
      header "Verifying sha512"
      if ( cd "$MNT" && curl -fLs -O "${TARBALL_URL}.sha512" ); then
        ( cd "$MNT" && sha512sum -c "${TB}.sha512" ) || die "checksum mismatch — aborting"
        rm -f "${MNT:?}/${TB:?}.sha512"
      else
        warn "no .sha512 published for this tarball — skipping verification"
      fi
    fi
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
  write /etc/default/grub <<GRUB_END
GRUB_DISTRIBUTOR="SourceMage"
GRUB_TIMEOUT=3
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_END
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

# ── Resume path: remount what a fresh install would have mounted ──────────────
do_resume() {
  header "Resuming existing install"
  is_mounted "$MNT" || run mount "$ROOT" "$MNT"
  is_mounted "$MNT/boot/efi" || { run mkdir -p "$MNT/boot/efi"; run mount "$EFI" "$MNT/boot/efi"; }
  run swapon "$SWAP" 2>/dev/null || true
}

if [[ $MODE == fresh ]]; then do_fresh; else do_resume; fi
write_profile_config

# ── The in-chroot phase, written out as a real script (no quoting soup) ───────
header "Preparing chroot"
for d in dev proc sys; do is_mounted "$MNT/$d" || run mount --rbind "/$d" "$MNT/$d"; done
run cp -L /etc/resolv.conf "$MNT/etc/resolv.conf"

SPELLS=("${SPELLS_CORE[@]}")
if [[ $PROFILE == macbookair ]]; then SPELLS+=("${SPELLS_MAC[@]}"); else SPELLS+=("${SPELLS_VM[@]}"); fi
$INSTALL_DESKTOP && SPELLS+=("${SPELLS_DESKTOP[@]}")

write /root/sm-chroot.sh <<CHROOT_END
#!/bin/bash
set -uo pipefail
export HOME=/root
echo "── Syncing grimoire (scribe update)"
scribe update || echo "warn: scribe update failed — using the grimoire snapshot from the tarball"

have_spell() { find /var/lib/sorcery/codex -mindepth 2 -maxdepth 2 -type d -name "\$1" 2>/dev/null | grep -q .; }
WANT=(${SPELLS[*]})
CAST=(); for s in "\${WANT[@]}"; do
  if have_spell "\$s"; then CAST+=("\$s"); else echo "warn: spell '\$s' not in the grimoire — skipping"; fi
done

# Kernel first, bootloader second: a bootable system exists even if a later
# desktop cast fails. The linux spell opens a kernel config menu — see the
# README for the options this machine needs built IN (no initramfs).
echo "── Casting: \${CAST[*]}"
for s in linux grub2 efibootmgr; do
  [[ " \${CAST[*]} " == *" \$s "* ]] && { cast "\$s" || echo "warn: cast \$s failed (re-run ./install.sh resume)"; }
done

echo "── Installing GRUB (UEFI, removable path — works on OVMF and Apple EFI)"
grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable || echo "warn: grub-install --removable failed"
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=SourceMage 2>/dev/null || true
grub-mkconfig -o /boot/grub/grub.cfg || echo "warn: grub-mkconfig failed"

REST=(); for s in "\${CAST[@]}"; do case "\$s" in linux|grub2|efibootmgr) ;; *) REST+=("\$s") ;; esac; done
((\${#REST[@]})) && { cast "\${REST[@]}" || echo "warn: some casts failed — re-run: ./install.sh resume"; }

echo "── Set the root password"; passwd root
if [[ -n "$USER_NAME" ]]; then
  id "$USER_NAME" >/dev/null 2>&1 || useradd -m "$USER_NAME"
  echo "── Set the password for $USER_NAME"; passwd "$USER_NAME"
fi
CHROOT_END
run chmod +x "$MNT/root/sm-chroot.sh"

header "Entering chroot to configure & build (this compiles from source)"
run chroot "$MNT" /bin/bash /root/sm-chroot.sh
run rm -f "${MNT:?}/root/sm-chroot.sh"

header "Cleaning up"
run umount -R "$MNT" || warn "could not unmount everything cleanly"
run swapoff "$SWAP" 2>/dev/null || true
echo -e "${GREEN}Done.${NC} Power off, detach the ISO, and boot the disk."
