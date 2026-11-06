# sourcemage — Source Mage GNU/Linux installer (sorcery, UEFI x86_64)

Same shape as `gentoo/`, `exherbo/` and `kiss/`: partition, unpack a base
system, fstab, chroot, then sync the grimoire and `cast`. **It wipes the target
disk and is UEFI-only.** Source-based: the kernel (and the desktop, if you
enable it) are compiled, so budget hours.

> **Status: not yet run end to end.** The scripts pass `bash -n` and a
> `DRY_RUN=1` walkthrough, and the tarball, checksum and spell names were
> checked against the live download server and the grimoire inside the tarball.
> Nobody has booted a result yet. Expect to fix something on the first real run.

## Install it in a VM (KVM)

```sh
./run-vm.sh
```

Makes a sparse 60G qcow2 + UEFI NVRAM, downloads the Gentoo minimal ISO the
first time, packs this directory into a read-only virtio disk and boots. In the
live shell:

```sh
mkdir -p /root/sm && tar xf /dev/vdb -C /root/sm
DISK=/dev/vda INSTALL_DESKTOP=no /root/sm/sourcemage/install.sh
```

Then power off and `./run-vm.sh` again to boot the installed disk. Use
`INSTALL_DESKTOP=yes` for Xorg + Xfce + Firefox (many more hours).
Needs `qemu-system-x86_64`, `qemu-img`, OVMF, and `/dev/kvm` access (without
KVM a source build takes days).

## Install on real hardware

```sh
PROFILE=macbookair DISK=/dev/sda ./install.sh
```

Re-running `./install.sh` on a disk that already has Sorcery resumes (no
wipe); a failed cast is fixed by running it again. `DRY_RUN=1` prints every
destructive command instead of running it.

## What it uses

| Piece | Choice |
|---|---|
| Base system | official `smgl-test-0.63-20251212_1200-basesystem-x86_64.tar.xz`, sha512-verified |
| Grimoire | `scribe update` (the tarball ships a snapshot; spell names are re-checked in the chroot and missing ones are skipped with a warning) |
| Bootloader | `grub2`, installed to the removable path (works on OVMF and Apple EFI) |
| Layout | 512M ESP · 4G swap · ext4 root (override with `ESP_SIZE`, `SWAP_SIZE`) |

## You must configure the kernel (no initramfs)

The `linux` spell opens a kernel config menu. There is no initramfs, so the
drivers needed to reach the root filesystem must be built **in** (`=y`, not `=m`):

- **VM:** `VIRTIO_PCI`, `VIRTIO_BLK`, `VIRTIO_NET`, `EXT4_FS`, `EFI`/`EFI_STUB`,
  `DEVTMPFS` + `DEVTMPFS_MOUNT`, `DRM_VIRTIO_GPU` (or `DRM_SIMPLEDRM`) for a console.
- **MacBook Air (Haswell):** `SATA_AHCI`, `EXT4_FS`, `EFI`/`EFI_STUB`, `DRM_I915`,
  `SND_HDA_INTEL` + `SND_HDA_CODEC_CIRRUS`, `SENSORS_APPLESMC`, `X86_INTEL_PSTATE`.

## MacBook Air notes (i5-4250U, HD 5000, CS4208, Apple EFI)

- **Broadcom BCM4360 WiFi has no spell in the grimoire.** There is no
  `broadcom-wl`/`broadcom-sta`, and `b43`/`bcm43xx-fwcutter` do not support the
  BCM4360. Use a USB Ethernet adapter or a phone USB tether during the install;
  getting WiFi afterwards means writing a local spell for the proprietary `wl` driver.
- Microcode is the `microcode_ctl` spell (not `intel-microcode`); there is no
  `mbpfan` spell, so fan control is left to the firmware.
- Audio gets `snd-hda-intel model=mba6`; if silent, try `model=auto` in
  `/etc/modprobe.d/sound.conf`.
- Apple EFI ignores most `efibootmgr` entries, hence the removable-path GRUB.
  Hold Option at power-on to pick the disk.

## Spell lists

Edit `SPELLS_CORE`, `SPELLS_MAC`, `SPELLS_DESKTOP` at the top of `install.sh`.
There is no `xfce4` meta spell, so the desktop is the individual
`xfce4-*`/`xfwm4`/`xfdesktop`/`thunar` spells on top of `xorg-server` + `xinit`.
