#!/usr/bin/env bash
# =============================================================================
# Source Mage in a VM — set EVERYTHING up with one command (qemu + OVMF UEFI).
#
#   ./setup-vm.sh            install (first run / resume an interrupted one), then boot the desktop
#   ./setup-vm.sh install    install only, don't boot afterwards
#   ./setup-vm.sh boot       just boot the installed system
#
# What it does, on your machine, as your user (nothing is installed on the host):
#   1. checks qemu / OVMF / python3 and KVM, asks for user name + passwords once
#   2. creates a sparse disk + UEFI NVRAM, downloads the Gentoo live ISO
#   3. boots the live ISO headless, packs install.sh + rice into a read-only disk (/dev/vdb)
#   4. TYPES the installer into the guest over the serial console (vm-drive.py) and streams its output:
#      partition -> base system -> kernel -> GRUB -> Xorg/bspwm/st/dillo/neovim rice
#   5. powers the live system off and boots the installed one in a window
#
# Resumable: Ctrl-C or a failure leaves the disk as it is; run ./setup-vm.sh again and install.sh picks up where
# it stopped (spells already cast are skipped). The disk is never deleted by this script — to start over,
# remove $VM_DIR yourself.
#
# Options (env), all optional:
#   USER_NAME=legend  KB_LAYOUT=se  HOSTNAME_=sourcemage  TIMEZONE=Europe/Stockholm
#   ROOT_PASSWORD=... USER_PASSWORD=...     (asked for if you don't set them; random if there is no terminal)
#   INSTALL_DESKTOP=yes|no                  (default yes; "no" = console system, a much shorter build)
#   PROFILE=vm  DISK_SIZE=60G  MEM=4G  CPUS=N  SSH_PORT=2222  VM_DIR=~/sourcemage-vm
#   ISO=/path.iso | ISO_URL=...             Gentoo minimal install ISO (downloaded to ~/live.iso if missing)
#   CA_BUNDLE=/path.pem                     extra CA file for a TLS-inspecting proxy (used in live + chroot)
#   DRY_RUN=1                               boot the live ISO and run install.sh in dry-run mode (changes nothing)
#   DISPLAY_TYPE=gtk|sdl|none               none = headless, VNC on localhost:5900
#   FW_CODE=/path/OVMF_CODE.fd FW_VARS=...  firmware, if auto-detection fails
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YEL='\033[0;33m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
warn()   { echo -e "${YEL}warn:${NC} $*" >&2; }
die()    { echo -e "${RED}error:${NC} $*" >&2; exit 1; }
[[ ${EUID:-$(id -u)} -eq 0 ]] && die "run as your user, not root (the VM window and /dev/kvm are yours)"

SELF_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
DRIVE=(python3 -I "$SELF_DIR/vm-drive.py")
VM_DIR="${VM_DIR:-$HOME/sourcemage-vm}"
DISK="$VM_DIR/sourcemage.qcow2"                     # same file run-vm.sh uses
NVRAM="$VM_DIR/OVMF_VARS.fd"
STATE="$VM_DIR/state"                               # empty | installing | installed
INSTALLER_TAR="$VM_DIR/installer.tar"
LIVE_DIR="$VM_DIR/live"
SOCK="$VM_DIR/serial.sock"; LOG="$VM_DIR/serial.log"; MON="$VM_DIR/monitor.sock"
DISK_SIZE="${DISK_SIZE:-60G}"; MEM="${MEM:-4G}"; CPUS="${CPUS:-$(nproc)}"; SSH_PORT="${SSH_PORT:-2222}"
ISO="${ISO:-$HOME/live.iso}"
ISO_URL="${ISO_URL:-https://distfiles.gentoo.org/releases/amd64/autobuilds/20260913T163055Z/install-amd64-minimal-20260913T163055Z.iso}"
FW_CODE="${FW_CODE:-}"; FW_VARS="${FW_VARS:-}"
PROFILE="${PROFILE:-vm}"
INSTALL_DESKTOP="${INSTALL_DESKTOP:-yes}"
HOSTNAME_="${HOSTNAME_:-sourcemage}"
KB_LAYOUT="${KB_LAYOUT:-se}"
TIMEZONE="${TIMEZONE:-$( (readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||') || true)}"
TIMEZONE="${TIMEZONE:-America/New_York}"
USER_NAME="${USER_NAME:-}"
DRY_RUN="${DRY_RUN:-0}"
CA_BUNDLE="${CA_BUNDLE:-}"
QPID=""

MODE="${1:-all}"
case "$MODE" in all|install|boot) ;; -h|--help) sed -n '2,36p' "$0"; exit 0 ;; *) die "usage: $0 [install|boot]" ;; esac

# ── 1. prerequisites ──────────────────────────────────────────────────────────
command -v qemu-system-x86_64 >/dev/null || die "qemu-system-x86_64 not found (Gentoo: doas emerge app-emulation/qemu)"
command -v qemu-img >/dev/null || die "qemu-img not found"
command -v python3 >/dev/null || die "python3 not found (needed by vm-drive.py)"
if [[ -z "$FW_CODE" ]]; then
  for d in /usr/share/edk2/ovmf /usr/share/edk2-ovmf /usr/share/OVMF /usr/share/qemu /usr/share/edk2 /usr/share/edk2/x64; do
    for c in OVMF_CODE.fd OVMF_CODE.4m.fd OVMF_CODE_4M.fd; do
      [[ -f "$d/$c" ]] && { FW_CODE="$d/$c"; break 2; }
    done
  done
fi
[[ -f "$FW_CODE" ]] || die "OVMF firmware not found (Gentoo: doas emerge sys-firmware/edk2-bin) — or set FW_CODE=/path/OVMF_CODE.fd"
if [[ -z "$FW_VARS" ]]; then
  FW_VARS="${FW_CODE/OVMF_CODE/OVMF_VARS}"
  [[ -f "$FW_VARS" ]] || FW_VARS="$(dirname "$FW_CODE")/OVMF_VARS.fd"
fi
[[ -f "$FW_VARS" ]] || die "OVMF_VARS not found next to $FW_CODE — set FW_VARS=/path/OVMF_VARS.fd"

if [[ -w /dev/kvm ]]; then ACCEL=(-accel kvm -cpu host)
else
  warn "no write access to /dev/kvm — running WITHOUT acceleration. The source build would take days; add yourself to the kvm group and log in again."
  ACCEL=(-accel tcg,thread=multi -cpu max)
fi

mkdir -p "$VM_DIR"; chmod 700 "$VM_DIR"           # the serial log can hold what the install prints: keep it private
STATUS="$(cat "$STATE" 2>/dev/null || true)"

# ── display for the final boot ────────────────────────────────────────────────
DISPLAY_TYPE="${DISPLAY_TYPE:-}"
if [[ -z "$DISPLAY_TYPE" ]]; then
  for d in gtk sdl; do
    qemu-system-x86_64 -display help 2>/dev/null | grep -qw "$d" && { DISPLAY_TYPE="$d"; break; }
  done
fi
if [[ -n "$DISPLAY_TYPE" && "$DISPLAY_TYPE" != none ]]; then DISP=(-vga std -display "$DISPLAY_TYPE")
else DISP=(-vga std -display none -vnc 127.0.0.1:0); fi

qemu_base() {
  QEMU=(qemu-system-x86_64 -machine q35 "${ACCEL[@]}" -smp "$CPUS" -m "$MEM"
        -drive "if=pflash,format=raw,readonly=on,file=$FW_CODE"
        -drive "if=pflash,format=raw,file=$NVRAM"
        -drive "file=$DISK,if=virtio,format=qcow2"
        -netdev "user,id=n0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22" -device virtio-net-pci,netdev=n0
        -chardev "socket,id=s0,path=$SOCK,server=on,wait=off,logfile=$LOG,logappend=off" -serial chardev:s0)
}

# ── boot only ─────────────────────────────────────────────────────────────────
boot_installed() {
  header "Booting the installed system"
  qemu_base
  rm -f "$SOCK"
  echo -e "  login on the console / window; ssh: ${GREEN}ssh -p $SSH_PORT <user>@localhost${NC} (VNC: localhost:5900 if headless)"
  if [[ "${DISPLAY_TYPE}" == none ]]; then echo "  headless — press Ctrl-C to stop"; fi
  "${QEMU[@]}" "${DISP[@]}" &
  QPID=$!
  ( VM_PID=$QPID FROM_START=1 "${DRIVE[@]}" "$SOCK" "$LOG" wait 'login:' 600 >/dev/null 2>&1 \
      && echo -e "  ${GREEN}booted: the login prompt is up${NC}" || true ) &
  wait "$QPID" || true
}

if [[ "$MODE" == boot ]]; then
  [[ -f "$DISK" ]] || die "no disk yet — run ./setup-vm.sh first"
  [[ -f "$NVRAM" ]] || cp "$FW_VARS" "$NVRAM"
  boot_installed; exit 0
fi

# ── settings (asked once, then the whole install is hands-off) ────────────────
if [[ "$STATUS" != installed ]]; then
  if [[ -t 0 && -t 1 ]]; then
    [[ -n "$USER_NAME" ]] || { read -rp "User name for the desktop [${USER}]: " USER_NAME; USER_NAME="${USER_NAME:-$USER}"; }
    if [[ -z "${ROOT_PASSWORD:-}" ]]; then
      while :; do
        read -rsp "Root password: " p1; echo; read -rsp "Again: " p2; echo
        [[ -n "$p1" && "$p1" == "$p2" ]] && { ROOT_PASSWORD="$p1"; break; }; echo "empty or different, try again"
      done
    fi
    USER_PASSWORD="${USER_PASSWORD:-$ROOT_PASSWORD}"
  else
    USER_NAME="${USER_NAME:-$USER}"
    if [[ -z "${ROOT_PASSWORD:-}" ]]; then
      ROOT_PASSWORD="$(head -c 18 /dev/urandom | base64 | tr -d '/+=' | head -c 16)"
      echo -e "${YEL}no terminal and no ROOT_PASSWORD: generated one — root and ${USER_NAME} password: ${ROOT_PASSWORD}${NC}"
    fi
    USER_PASSWORD="${USER_PASSWORD:-$ROOT_PASSWORD}"
  fi
  [[ "$DRY_RUN" == 1 ]] && { ROOT_PASSWORD="${ROOT_PASSWORD:-dry}"; USER_PASSWORD="${USER_PASSWORD:-dry}"; }
fi

# ── 2. disk, firmware, ISO ────────────────────────────────────────────────────
cleanup() {
  trap - INT TERM EXIT
  if [[ -n "$QPID" ]] && kill -0 "$QPID" 2>/dev/null; then
    echo -e "\n${YEL}stopping the VM — run ./setup-vm.sh again to resume${NC}"
    "${DRIVE[@]}" "$SOCK" "$LOG" send '\x03' 2>/dev/null || true; sleep 3
    "${DRIVE[@]}" "$SOCK" "$LOG" send 'sync; poweroff -f\n' 2>/dev/null || true; sleep 4
    kill "$QPID" 2>/dev/null || true
  fi
}
trap 'cleanup; exit 130' INT TERM
trap cleanup EXIT

[[ -f "$DISK" ]] || { header "Creating disk $DISK ($DISK_SIZE, sparse)"; qemu-img create -f qcow2 "$DISK" "$DISK_SIZE" >/dev/null; }
header "Resetting UEFI NVRAM"; cp "$FW_VARS" "$NVRAM"     # a stale boot order would skip the live medium

if [[ ! -f "$ISO" ]]; then
  command -v curl >/dev/null || die "curl not found — needed to fetch the ISO"
  header "Downloading the Gentoo live ISO -> $ISO"
  curl -fL# -o "$ISO.part" "$ISO_URL" && mv "$ISO.part" "$ISO" || die "ISO download failed ($ISO_URL) — pass ISO=/path.iso"
fi

# The live ISO is booted with -kernel/-initrd so the console is the serial line we can type into.
extract_boot() {
  mkdir -p "$LIVE_DIR"
  [[ -s "$LIVE_DIR/gentoo" && -s "$LIVE_DIR/gentoo.igz" && -f "$LIVE_DIR/for" && "$(cat "$LIVE_DIR/for")" == "$ISO:$(stat -c %s "$ISO")" ]] && return 0
  header "Extracting kernel + initramfs from the ISO"
  if command -v xorriso >/dev/null; then
    xorriso -osirrox on -indev "$ISO" -extract /boot/gentoo "$LIVE_DIR/gentoo" -extract /boot/gentoo.igz "$LIVE_DIR/gentoo.igz" >/dev/null 2>&1
  elif command -v bsdtar >/dev/null; then
    bsdtar -xf "$ISO" -C "$LIVE_DIR" --strip-components=1 boot/gentoo boot/gentoo.igz
  elif command -v 7z >/dev/null; then
    7z e -y -o"$LIVE_DIR" "$ISO" boot/gentoo boot/gentoo.igz >/dev/null
  else
    die "need xorriso, bsdtar or 7z to unpack the ISO's kernel (Gentoo: doas emerge dev-libs/libisoburn)"
  fi
  [[ -s "$LIVE_DIR/gentoo" && -s "$LIVE_DIR/gentoo.igz" ]] || die "could not find boot/gentoo + boot/gentoo.igz in $ISO (is it a Gentoo minimal ISO?)"
  echo "$ISO:$(stat -c %s "$ISO")" > "$LIVE_DIR/for"
}
extract_boot
LABEL=""
command -v xorriso >/dev/null && LABEL="$(xorriso -indev "$ISO" -pvd_info 2>&1 | sed -n 's/^Volume Id *: *//p' | head -1)"
ROOT_ARG="root=live:${LABEL:+CDLABEL=$LABEL}"; [[ -n "$LABEL" ]] || ROOT_ARG="root=live:/dev/sr0"

# ── 3. boot the live system headless ──────────────────────────────────────────
header "Packing installer -> $INSTALLER_TAR"
tar -cf "$INSTALLER_TAR" -C "$SELF_DIR" install.sh README.md grimoire rice kernel

header "Booting the live ISO (headless, serial console)"
qemu_base
rm -f "$SOCK" "$LOG"
QEMU+=(-display none -monitor "unix:$MON,server,nowait"
       -kernel "$LIVE_DIR/gentoo" -initrd "$LIVE_DIR/gentoo.igz"
       -append "dokeymap $ROOT_ARG rd.live.dir=/ rd.live.squashimg=image.squashfs cdroot rd.live.ram=1 console=ttyS0,115200n8"
       -drive "file=$ISO,media=cdrom,readonly=on,if=none,id=cd0" -device ide-cd,drive=cd0
       -drive "file=$INSTALLER_TAR,if=virtio,format=raw,readonly=on")
rm -f "$MON"
"${QEMU[@]}" >/dev/null 2>"$VM_DIR/qemu.err" &
QPID=$!
export VM_PID=$QPID
sleep 1; kill -0 "$QPID" 2>/dev/null || { cat "$VM_DIR/qemu.err" >&2; die "qemu failed to start"; }
chmod 600 "$LOG" 2>/dev/null || true

echo "  waiting for the live system (a few minutes without KVM) ..."
FROM_START=1 "${DRIVE[@]}" "$SOCK" "$LOG" wait 'root@livecd' 900 >/dev/null || die "the live system did not come up — see $LOG"
sleep 2
g() { "${DRIVE[@]}" "$SOCK" "$LOG" run "$@"; }     # run a command in the guest, stream its output, return its status

g 'export PS1="# "; stty cols 200; echo live shell ready' 30 >/dev/null

if [[ -n "$CA_BUNDLE" ]]; then
  [[ -f "$CA_BUNDLE" ]] || die "CA_BUNDLE not found: $CA_BUNDLE"
  "${DRIVE[@]}" "$SOCK" "$LOG" put "$CA_BUNDLE" /root/ca.pem || die "could not copy CA_BUNDLE into the guest"
  g 'export CURL_CA_BUNDLE=/root/ca.pem SSL_CERT_FILE=/root/ca.pem' 30 >/dev/null
fi

header "Checking the guest's network"
g 'for i in $(seq 30); do curl -fsS -o /dev/null -m 8 https://download.sourcemage.org/ && exit 0; sleep 3; done; exit 1' 200 \
  || die "the guest has no internet (user-mode NAT should give it one: check the host's connection / proxy, CA_BUNDLE)"

g 'mkdir -p /root/sm && tar xf /dev/vdb -C /root/sm && chmod +x /root/sm/install.sh && ls /root/sm' 60 >/dev/null || die "could not unpack the installer in the guest"

# Credentials go in with the terminal's echo off, so they never land in the serial log.
if [[ "$DRY_RUN" != 1 ]]; then
  g "stty -echo; export ROOT_PASSWORD=$(printf %q "$ROOT_PASSWORD") USER_PASSWORD=$(printf %q "$USER_PASSWORD"); stty echo" 30 >/dev/null
fi

# ── 4. the install itself ─────────────────────────────────────────────────────
echo "installing" > "$STATE"
header "Installing (profile=$PROFILE desktop=$INSTALL_DESKTOP user=$USER_NAME kb=$KB_LAYOUT jobs=$CPUS)"
ENVS="UNATTENDED=1 ASSUME_YES=1 DISK=/dev/vda PROFILE=$PROFILE INSTALL_DESKTOP=$INSTALL_DESKTOP"
ENVS+=" HOSTNAME_=$(printf %q "$HOSTNAME_") TIMEZONE=$(printf %q "$TIMEZONE") KB_LAYOUT=$(printf %q "$KB_LAYOUT") USER_NAME=$(printf %q "$USER_NAME") JOBS=$CPUS"
[[ -n "$CA_BUNDLE" ]] && ENVS+=" CA_BUNDLE=/root/ca.pem"
[[ "$DRY_RUN" == 1 ]] && ENVS+=" DRY_RUN=1"
RC=0
g "$ENVS /root/sm/install.sh" 604800 || RC=$?

if [[ $RC -ne 0 ]]; then
  echo
  die "the installer stopped (exit $RC). Fix what it printed above, then run ./setup-vm.sh again to resume. Log: $LOG"
fi
if [[ "$DRY_RUN" == 1 ]]; then
  g 'poweroff -f' 20 >/dev/null || true; sleep 3
  echo -e "\n${GREEN}dry run finished — nothing was changed on the disk${NC}"; echo "" > "$STATE"; exit 0
fi

echo "installed" > "$STATE"
header "Install finished — powering the live system off"
g 'sync' 60 >/dev/null || true
"${DRIVE[@]}" "$SOCK" "$LOG" send 'poweroff\n' || true
for _ in $(seq 60); do kill -0 "$QPID" 2>/dev/null || break; sleep 1; done
kill "$QPID" 2>/dev/null || true; QPID=""
trap - INT TERM EXIT

# ── 5. boot the result ────────────────────────────────────────────────────────
echo -e "${GREEN}Source Mage is installed on $DISK${NC}  (users: root, ${USER_NAME})"
if [[ "$MODE" == install ]]; then echo "boot it any time with ./setup-vm.sh boot (or ./run-vm.sh boot)"; exit 0; fi
cp "$FW_VARS" "$NVRAM"
boot_installed
