#!/usr/bin/env bash
# =============================================================================
# Source Mage in a VM (KVM/qemu + OVMF UEFI). One command:
#
#   ./run-vm.sh            first run -> INSTALL mode; afterwards -> BOOT the
#                          installed system
#   ./run-vm.sh install    force install mode again (resets UEFI NVRAM)
#   ./run-vm.sh boot       boot the installed disk
#   ./run-vm.sh /x.iso     install using a specific live ISO
#   ./run-vm.sh pack       just rebuild the installer disk (after editing install.sh)
#
# How the installer gets into the guest: this script packs install.sh into a
# tarball and attaches it READ-ONLY as a 2nd virtio disk (/dev/vdb). In the
# live ISO's shell:
#
#       mkdir -p /root/sm && tar xf /dev/vdb -C /root/sm
#       DISK=/dev/vda INSTALL_DESKTOP=no /root/sm/install.sh
#
# (the guest's NAT network gives it internet; no 9p / no git clone needed).
# `ssh -p 2222 root@localhost` also works once you set a root password in the
# live env and start sshd.
#
# Tunables (env): VM_DIR DISK_SIZE MEM CPUS SSH_PORT FW_CODE FW_VARS
#                 DISPLAY_TYPE ISO_DEFAULT ISO_URL
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YEL='\033[0;33m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
warn()   { echo -e "${YEL}warn:${NC} $*" >&2; }
die()    { echo -e "${RED}error:${NC} $*" >&2; exit 1; }

# Run as your user: the GUI needs your own display session, and /dev/kvm access
# comes from the kvm group, not root.
[[ ${EUID:-$(id -u)} -eq 0 ]] && die "run as your user, not root"

SELF_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"   # repo root
VM_DIR="${VM_DIR:-$HOME/sourcemage-vm}"
DISK="$VM_DIR/sourcemage.qcow2"
INSTALLER_TAR="$VM_DIR/installer.tar"
# A source build of the bspwm desktop (Xorg, bspwm, dillo, neovim) needs real room; qcow2 is sparse so this
# costs nothing until used.
DISK_SIZE="${DISK_SIZE:-60G}"
MEM="${MEM:-4G}"
CPUS="${CPUS:-$(nproc)}"
SSH_PORT="${SSH_PORT:-2222}"
ISO_DEFAULT="${ISO_DEFAULT:-$HOME/live.iso}"
# Gentoo minimal install ISO (UEFI-bootable; has sgdisk, mkfs, curl, chroot).
# Dated autobuilds rotate off the mirror — if this 404s, pass your own ISO or ISO_URL.
ISO_URL="${ISO_URL:-https://distfiles.gentoo.org/releases/amd64/autobuilds/20260913T163055Z/install-amd64-minimal-20260913T163055Z.iso}"
FW_CODE="${FW_CODE:-}"; FW_VARS="${FW_VARS:-}"

detect_fw() {
  [[ -n "$FW_CODE" ]] && return 0
  local d c
  for d in /usr/share/edk2/ovmf /usr/share/edk2-ovmf /usr/share/OVMF /usr/share/qemu /usr/share/edk2 /usr/share/edk2/x64; do
    for c in OVMF_CODE.fd OVMF_CODE.4m.fd OVMF_CODE_4M.fd; do
      [[ -f "$d/$c" ]] && { FW_CODE="$d/$c"; return 0; }
    done
  done
  return 1
}

command -v qemu-system-x86_64 >/dev/null 2>&1 || die "qemu-system-x86_64 not found (Gentoo: doas emerge app-emulation/qemu, QEMU_SOFTMMU_TARGETS=x86_64)"
command -v qemu-img >/dev/null 2>&1 || die "qemu-img not found"
detect_fw || die "OVMF firmware not found (Gentoo: doas emerge sys-firmware/edk2-bin) — or set FW_CODE=/path/OVMF_CODE.fd"
mkdir -p "$VM_DIR"

# ── Pack the installer into a tar that is attached as a read-only disk ────────
pack_installer() {
  header "Packing installer -> $INSTALLER_TAR"
  tar -cf "$INSTALLER_TAR" -C "$SELF_DIR" install.sh README.md grimoire rice kernel
}

ARG="${1:-}"; ISO=""
case "$ARG" in
  pack)    pack_installer; exit 0 ;;
  boot)    MODE=boot ;;
  install) MODE=install; ISO="${2:-}" ;;
  "")      if [[ -f "$DISK" ]]; then MODE=boot; else MODE=install; fi ;;
  *)       MODE=install; ISO="$ARG" ;;
esac

# ── KVM access ────────────────────────────────────────────────────────────────
if [[ -w /dev/kvm ]]; then
  ACCEL=(-enable-kvm -cpu host)
else
  warn "no write access to /dev/kvm — running WITHOUT acceleration (a source build would take days). Add yourself to the kvm group and re-login."
  ACCEL=(-cpu max)
fi

# ── Firmware vars (writable NVRAM copy) ───────────────────────────────────────
if [[ -z "$FW_VARS" ]]; then
  FW_VARS="${FW_CODE/OVMF_CODE/OVMF_VARS}"
  [[ -f "$FW_VARS" ]] || FW_VARS="$(dirname "$FW_CODE")/OVMF_VARS.fd"
fi
[[ -f "$FW_VARS" ]] || die "OVMF_VARS not found next to $FW_CODE — set FW_VARS=/path/OVMF_VARS.fd"
NVRAM="$VM_DIR/OVMF_VARS.fd"
# Install mode always starts from a factory boot order: a stale one makes OVMF
# skip the CD and fall through to the empty disk.
if [[ ! -f "$NVRAM" || "$MODE" == install ]]; then
  header "Resetting UEFI NVRAM -> $NVRAM"
  cp "$FW_VARS" "$NVRAM"
fi
[[ -f "$DISK" ]] || { header "Creating disk $DISK ($DISK_SIZE)"; qemu-img create -f qcow2 "$DISK" "$DISK_SIZE" >/dev/null; }

# ── Display ───────────────────────────────────────────────────────────────────
DISPLAY_TYPE="${DISPLAY_TYPE:-}"
if [[ -z "$DISPLAY_TYPE" ]]; then
  for d in gtk sdl; do
    qemu-system-x86_64 -display help 2>/dev/null | grep -qw "$d" && { DISPLAY_TYPE="$d"; break; }
  done
fi
if [[ -n "$DISPLAY_TYPE" ]]; then DISP=(-vga std -display "$DISPLAY_TYPE")
else warn "no gtk/sdl display in this qemu — using VNC on localhost:5900"; DISP=(-vga std -display none -vnc :0); fi

ARGS=(
  "${ACCEL[@]}"
  -machine q35
  -m "$MEM" -smp "$CPUS"
  -drive "if=pflash,format=raw,readonly=on,file=$FW_CODE"
  -drive "if=pflash,format=raw,file=$NVRAM"
  -drive "file=$DISK,if=virtio,format=qcow2"
  -netdev "user,id=n0,hostfwd=tcp::${SSH_PORT}-:22" -device virtio-net-pci,netdev=n0
  "${DISP[@]}"
)

if [[ "$MODE" == install ]]; then
  [[ -n "$ISO" ]] || ISO="$ISO_DEFAULT"
  if [[ ! -f "$ISO" ]]; then
    [[ "$ISO" == "$ISO_DEFAULT" ]] || die "ISO not found: $ISO"
    command -v curl >/dev/null 2>&1 || die "curl not found — needed to fetch the ISO"
    header "No ISO at $ISO — downloading Gentoo minimal"
    curl -fL# -o "$ISO" "$ISO_URL" || { rm -f "$ISO"; die "ISO download failed ($ISO_URL) — pass your own ISO"; }
  fi
  pack_installer
  ARGS+=(-cdrom "$ISO" -boot menu=on -drive "file=$INSTALLER_TAR,if=virtio,format=raw,readonly=on")
  header "Install mode — booting $ISO"
  echo -e "  ${GREEN}In the live shell, run:${NC}"
  echo "    mkdir -p /root/sm && tar xf /dev/vdb -C /root/sm"
  echo "    DISK=/dev/vda INSTALL_DESKTOP=no /root/sm/install.sh"
  echo "  (set INSTALL_DESKTOP=yes for the bspwm desktop + rice: many extra hours)"
else
  header "Boot mode — starting the installed system"
fi
echo -e "  mem=$MEM  cpus=$CPUS  disk=$DISK_SIZE (sparse)\n  firmware=$FW_CODE"

exec qemu-system-x86_64 "${ARGS[@]}"
