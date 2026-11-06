# Source-Mage-gnu — Source Mage GNU/Linux installer (sorcery, UEFI x86_64)

Same shape as `gentoo/`, `exherbo/` and `kiss/`: partition, unpack a base
system, fstab, chroot, then sync the grimoire and `cast`. **It wipes the target
disk and is UEFI-only.** Source-based: the kernel (and the desktop, if you
enable it) are compiled, so budget hours.

> **Status: partly tested — see "Test status" below.** The installer was run in QEMU
> up to a booting base system; the compile steps (kernel, `grub2`, desktop) and real
> hardware have not been exercised. Expect to fix something on the first real run.

## Install it in a VM (KVM)

```sh
./run-vm.sh
```

Makes a sparse 60G qcow2 + UEFI NVRAM, downloads the Gentoo minimal ISO the
first time, packs the installer into a read-only virtio disk and boots. In the
live shell:

```sh
mkdir -p /root/sm && tar xf /dev/vdb -C /root/sm
DISK=/dev/vda INSTALL_DESKTOP=no /root/sm/install.sh
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

## Test status (QEMU, no KVM, software emulation)

Run end to end in QEMU/OVMF from the Gentoo minimal ISO, following the steps above:

| Step | Result |
|---|---|
| `tar xf /dev/vdb` unpack of the installer, documented `install.sh` command | works |
| GPT partitioning, `mkfs.fat` / `mkswap` / `mkfs.ext4`, UUID `fstab` | works |
| Download + sha512 verification + unpack of the base tarball, `fresh` over an old install | works |
| `resume` mode, `scribe update`, spell lookup, interactive `cast` prompts | works; `cast linux` started building `elfutils` |
| Failure reporting (`FAILED STEPS: …`, non-zero exit) | works |
| UEFI boot: OVMF → `EFI/BOOT/BOOTX64.EFI` (GRUB 2.14) → kernel → ext4 root → `simpleinit` → runlevel 3 → **login prompt on the VGA console and on serial; root login works** | works with the tarball's stock 3.4.51 kernel (disk attached as SATA) |
| `cast linux`, `cast grub2` (so `grub-install`/`grub-mkconfig` as the installer runs them), the desktop, a kernel built by the `linux` spell, real hardware | **not tested**: a source build is far too slow without KVM. The boot above used the live ISO's GRUB with a hand-written `grub.cfg` that mirrors `/etc/default/grub` |

Things this uncovered, now handled or worth knowing:

- The base tarball's stock kernel has `VIRTIO_BLK=m` and there is no initramfs, so it
  cannot boot from `run-vm.sh`'s virtio disk. Build your own kernel with the drivers in.
- Modern `mkfs.ext4` defaults (`metadata_csum_seed`, …) are rejected by that old kernel,
  so root is formatted with conservative features (`EXT4_OPTS`, see `install.sh`).
- Init stalled after udev coldplug (`Error opening …/dev/initctl`) until the kernel was given
  `devtmpfs.mount=1`: `simpleinit` keeps its FIFO in `/dev`. The installer now writes that into
  `/etc/default/grub`, plus `GRUB_GFXPAYLOAD_LINUX=keep` (otherwise the screen stays blank),
  `GRUB_DISABLE_LINUX_UUID=true` (no initramfs, so `root=UUID=` cannot resolve), and, for the
  `vm` profile, a serial getty in `/etc/inittab`.
- `cast` is interactive (e.g. `elfutils` vs `libelf`, initramfs, optional dependencies, the
  kernel menu): press Enter for the defaults. Unattended installs are not supported.
- `SKIP_CHROOT=1` stops after unpacking the base system; `CA_BUNDLE=` trusts an extra CA
  inside the chroot (TLS-inspecting proxies).

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
- **Always:** `DEVTMPFS` **and `DEVTMPFS_MOUNT=y`** (init stalls without it; the installer also
  passes `devtmpfs.mount=1`), `FB_EFI` or `DRM_SIMPLEDRM` + `FRAMEBUFFER_CONSOLE` for a visible console.
- **MacBook Air (Haswell):** `SATA_AHCI`, `EXT4_FS`, `EFI`/`EFI_STUB`, `DRM_I915`,
  `SND_HDA_INTEL` + `SND_HDA_CODEC_CIRRUS`, `SENSORS_APPLESMC`, `X86_INTEL_PSTATE`.

## MacBook Air notes (i5-4250U, HD 5000, CS4208, Apple EFI)

- **Broadcom BCM4360 WiFi: `broadcom-wl` is a local spell** in `grimoire/kernels/broadcom-wl/`
  (the official grimoire has none, and `b43` does not support the BCM4360). The
  installer copies it to `/var/lib/sorcery/codex/local` and registers it in
  `/etc/sorcery/local/grimoire`. It builds Broadcom's proprietary `wl` driver
  using Debian's 6.30.223.271-32 patch series (kernels 3.x–7.2), installs
  `wl.ko`, blacklists the conflicting `b43`/`ssb`/`bcma`/`brcmsmac` modules, and
  recasts itself whenever `linux` is cast. You still need **wired/tethered
  internet during the install** (WiFi only works after the first boot) and
  `CONFIG_CFG80211` in the kernel. Build-tested: `wl.ko` compiles and links against Linux 7.2.15
  (x86_64, CFG80211 built in) and every kernel symbol it needs is exported, but
  it has not been loaded on real BCM4360 hardware. Debian's series stops at
  kernel 7.2; on a newer kernel (e.g. 7.3) the build may fail until it is updated.
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
