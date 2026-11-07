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
`INSTALL_DESKTOP=yes` for Xorg + the bspwm rice + neovim (many more hours; see below).
Needs `qemu-system-x86_64`, `qemu-img`, OVMF, and `/dev/kvm` access (without
KVM a source build takes days).

## Install on real hardware

```sh
PROFILE=macbookair DISK=/dev/sda ./install.sh
```

Re-running `./install.sh` on a disk that already has Sorcery resumes (no
wipe); a failed cast is fixed by running it again. `DRY_RUN=1` prints every
destructive command instead of running it.

## Unattended install

```sh
UNATTENDED=1 ROOT_PASSWORD=... USER_NAME=legend INSTALL_DESKTOP=yes \
  DISK=/dev/vda ./install.sh
```

`UNATTENDED=1` closes stdin for the build, so every `cast` question takes its default, and builds
the newest kernel series the grimoire offers (detected after `scribe update`) from `kernel/vm.config`
(the `vm` profile; other profiles get plain `make defconfig`, so prefer the interactive kernel menu on
real hardware). Other knobs: `JOBS`, `SAVE_SPACE=1`, `SKIP_SPELLS`, `SKIP_EFI_CHECK=1` (install into a
disk image from a non-UEFI host), `USER_PASSWORD`, `CA_BUNDLE`, `SKIP_CHROOT=1`. A re-run skips spells
that are already installed.

**Why so many local spells.** Unattended "default" answers and the current grimoire do not produce a
working desktop on their own. `grimoire/` is a local grimoire (registered first, so it wins) that
carries the fixes found by actually building it:

| spell | problem in the official one | local fix |
|---|---|---|
| `dzen2` | downloads from `git://github.com`, a protocol GitHub switched off in 2022; Xft off | `git_http://` source, Xft always on |
| `picom` | `depends xcb`, which is an unrelated cut-buffer tool that needs (broken) `imake` | dependency removed |
| `rofi` | `yyparse` prototype error under GCC 15's C23 default | built as `-std=gnu17` |
| `dunst` | `dunstify` does not compile against libnotify 0.8 | build/install only daemon + `dunstctl` |
| `picom` (regex) | regex support wants libpcre; the optional dependency turns itself on once `pcre2` is installed, so the build broke on a fresh run | `regex=false` forced |
| `libnotify` | man pages default on, need `docbook-xsl-ns` (not in the grimoire) | man/docbook forced off |
| `libvterm` | demo tools fail to link under `slibtool` | `-L.libs` |
| `st` 0.9.2, `slock` 1.4 | suckless programs are configured at compile time; the grimoire builds stock defaults | your `legenddots` `config.h` is copied in before the build (Tokyo Night palette, 12px border, bar cursor; slock colours). Only change: font `JetBrains Mono` instead of the Nerd Font variant, which the grimoire does not have. Checked against each version's `config.def.h` (same settings); **not built or run yet** |
| `broadcom-wl` | does not exist (MacBook WiFi) | new spell, see below |

The installer also pre-seeds answers whose defaults are wrong: `grub2` (default is the BIOS build, so no
EFI modules), `mesa` (default is Wayland/ARM/Freedreno with no GLX and no EGL), `curl` (default has no
TLS, so `git` could not clone over https), and builds `curl` before `git`. `xorg-server` is now called
`xserver`; `xf86-input-evdev` is used instead of `libinput` (which wants Lua 5.4). Xorg is made setuid
(there is no logind) and the user joins `video`, `input` and `audio`.

## Test status

Run in this repo's author environment (4-core Linux VM, no KVM): the installer built a real system
into a disk image (natively in a chroot, then finished and booted under QEMU + OVMF):

| Step | Result |
|---|---|
| partition, `mkfs`, UUID `fstab`, base tarball download + sha512 + unpack, `fresh`/`resume` | works |
| `scribe update`, kernel **7.3.1** built from source by the `linux` spell, **GRUB 2.12** built by the `grub2` spell for x86_64-efi, dhcpcd, openssh, sudo, curl, git | works |
| `grub-install --removable` + `grub-mkconfig` in the chroot on a real FAT ESP | works |
| cold boot under UEFI: OVMF → GRUB → kernel 7.3.1 → ext4 root on a **virtio** disk → `simpleinit` → runlevel 3 → login on VGA and serial | works |
| desktop: Xorg, mesa (softpipe+virgl), bspwm, sxhkd, picom, rofi, dunst, st, slock, dzen2, neovim built from source; `startx` as a normal user shows the bspwm desktop with the Tokyo Night bar, `super+Return` opens `st`, neovim 0.11 starts | works (screenshots taken) |
| **Dillo** (your `dillorc`/`keysrc`) with TLS, PNG, JPEG, GIF and WebP, and **fastfetch** with your config | built; `super+w` opens Dillo tiled next to `st`, `fastfetch` runs in `st` |
| a from-scratch run of `install.sh` | **done**: one `fresh` run plus one `resume` built and booted the whole desktop. The fresh run exposed two more bugs, fixed afterwards and covered by the resume: `sudo` must be built after `neovim` (it asks for its editor provider and gets neovim), and `picom` regex. `slock` and `st` with your configs were run: the lock screen shows `#1a1b26`/`#7aa2f7` and unlocks with the password |
| `broadcom-wl` cast, MacBook hardware, rofi/neovim plugins over the network | not tested |

Boot details worth knowing (all handled by `install.sh`):

- Root is formatted with conservative ext4 features (`EXT4_OPTS`) so the base tarball's old 3.4.51 kernel can
  still mount it; that kernel has `VIRTIO_BLK=m` and no initramfs, so it cannot boot a virtio disk, which is
  why the installer builds its own kernel.
- `/etc/default/grub` gets `devtmpfs.mount=1` (without it `simpleinit` stalls: its `/dev/initctl` lives in
  `/dev`), `GRUB_GFXPAYLOAD_LINUX=keep` and `GRUB_DISABLE_LINUX_UUID=true` (no initramfs, so `root=UUID=` cannot
  resolve). The `vm` profile also adds a serial getty to `/etc/inittab`.
- Plain `make defconfig` has **no framebuffer console**, so a GUI window stays black; `kernel/vm.config` adds
  `DRM_SIMPLEDRM`, `DRM_BOCHS`, `DRM_FBDEV_EMULATION` and `FRAMEBUFFER_CONSOLE`.

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

## The bspwm desktop (`INSTALL_DESKTOP=yes`)

Same stack as your `legenddots/bspwm`: **bspwm** + **sxhkd**, **picom**, **rofi**, **dunst**,
**slock**, **st**, **Dillo**, Tokyo Night colours, Super as the mod key, plus **neovim**.
The one swap: the Source Mage grimoire has no `lemonbar`, so the bar is **dzen2** (also plain C,
fed from the same kind of shell loop: ram · battery · date). The files are in `rice/` and are
installed into `/etc/skel` (so new users get them), `/root`, and `USER_NAME` if you set it.

```sh
KB_LAYOUT=se USER_NAME=legend DISK=/dev/vda INSTALL_DESKTOP=yes ./install.sh
```

`KB_LAYOUT` (default `se`, as in legenddots) is the `setxkbmap` layout. There is no display
manager: log in on a console and run `startx` (`~/.xinitrc` is `exec bspwm`). `ly` is in the
grimoire if you want one. The browser is **Dillo** with your `dillorc`/`keysrc` (the legenddots rice uses
surf, which needs a 2015 WebKit that is hours of compiling and unlikely to build with GCC 15). fastfetch is
installed with your Tokyo Night config, minus the `logo.color` override: fastfetch's built-in Source Mage logo keeps its own colours.
`rice/fastfetch/fastfetch-html` turns the real fastfetch output (logo and system info) into
`~/fastfetch.html`: a Tokyo Night page with a stylesheet, written for Dillo (no JavaScript, basic CSS, so
tables and colours). bspwm regenerates it at login and `super+w` opens it in Dillo; `super+shift+w` opens a
blank Dillo. Run `~/.config/fastfetch/fastfetch-html` to refresh it by hand.

| key | action |
|---|---|
| `super-Return` / `super-e` | st / st running nvim |
| `super-p` / `super-w` | rofi / dillo |
| `super-q` / `super-shift-q` | close / kill window |
| `super-{h,j,k,l}` / with `shift` | focus / move in a direction |
| `super-{1..9}` / with `shift` | switch desktop / send window |
| `super-t`, `super-shift-space`, `super-f` | tiled, floating, fullscreen |
| `super-shift-x` | lock (slock, made setuid by the installer) |
| `super-alt-r` / `super-alt-q` | restart / quit bspwm |

**nvim** (`rice/nvim/init.lua`): a smaller version of your legenddots config. Same options and
leader (space), Tokyo Night, lazy.nvim, which-key, telescope, nvim-tree, treesitter, lualine,
gitsigns, indent guides. LSP/mason/cmp, noice and the dashboard are left out, and icons are off
because the grimoire has JetBrains Mono but not the Nerd Font. Plugins download on first launch
(needs `git` and network); `<leader>fg` (grep) needs `ripgrep`, which is not installed by default.

Tested: the rice ran in a virtual X server with the real bspwm, sxhkd, picom, dzen2 and st
(Ubuntu builds), including the key bindings, and the nvim config loaded cleanly on neovim 0.11.1
(the version the grimoire builds) with all plugins installed. Not tested: building these spells
on Source Mage, `dunst` (needs a D-Bus session), and treesitter parser downloads.
