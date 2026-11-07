# Source Mage vs Gentoo vs Exherbo

All three are source-based distributions whose package recipes are bash. This page goes
through where they agree and where they differ, and what that means for this installer.

## History and goals

- **Source Mage** descends from Sorcerer GNU/Linux (Kyle Sallee, 2001). In 2002 the Sorcerer
  GNU/Linux team kept developing after Sallee took his project offline and relicensed it, and
  at his request renamed theirs Source Mage. Its aim is to stay close to upstream: a spell
  downloads the source from the upstream project's own site, and only minimal patches are applied.
  Core tools need only bash, sed and an awk, with no Perl or Python.
- **Gentoo** is the largest of the three, with one big main tree and Portage, written in Python.
  It favours configuration up front (USE flags, profiles) and offers official binary packages too.
- **Exherbo** was started by former Gentoo developers. It keeps the ebuild-like shape but splits
  the package tree into many small repositories, with a small core team. Its package manager is
  Paludis (C++), and it treats source and binary packages on equal terms.

## What's similar

- Packages are compiled locally from bash recipes kept in git-synced repositories.
- Optional features are chosen before building, and dependencies follow from those choices.
- You can set your own CFLAGS/CXXFLAGS/LDFLAGS for the whole system.
- The install has the same shape: partition, unpack a base tarball (Source Mage's basesystem,
  Gentoo's stage3, Exherbo's stage), chroot, sync the repositories, build a kernel, install a
  bootloader. No graphical installer, and all three expect you to read what the build asks.
- Local repositories can override or add packages without touching the main tree.

## Package manager and equivalent commands

| Task | Source Mage (sorcery) | Gentoo (Portage) | Exherbo (Paludis) |
|---|---|---|---|
| Install | `cast foo` | `emerge -a foo` | `cave resolve -x foo` |
| Remove | `dispel foo` | `emerge --depclean foo` | `cave uninstall -x foo` |
| Sync repos | `scribe update` | `emerge --sync` | `cave sync` |
| Update everything | `sorcery queue` + `cast --queue` (or the `sorcery` menu) | `emerge -auDN @world` | `cave resolve -x world -c` |
| Search | `gaze search foo` | `emerge --search foo` | `cave search foo` |
| Show package info | `gaze what foo` | `emerge -pv foo` / `equery meta foo` | `cave show foo` |
| Which package owns a file | `gaze from /path` | `equery belongs /path` | `cave owner /path` |
| Fix broken linking | `cleanse --fix` | `emerge @preserved-rebuild` (`revdep-rebuild` is older) | `cave fix-linkage` |

`sorcery` with no arguments opens a dialog menu for settings, queues and spell options.

## Recipe format

- **Source Mage spell:** a directory with one file per step. `DETAILS` holds name, version,
  source URL, hash and description; `DEPENDS` declares dependencies and optional ones with
  `depends` / `optional_depends`; then optional `CONFIGURE` (ask questions), `PRE_BUILD`, `BUILD`,
  `INSTALL` and others. Any step left out falls back to a default (for example
  `./configure && make && make install`). This repo's `grimoire/` has real examples.
- **Gentoo ebuild:** one file per version (`foo-1.2.ebuild`) with variables (`SRC_URI`, `IUSE`,
  `DEPEND`, `RDEPEND`, `SLOT`, `KEYWORDS`) and phase functions (`src_prepare`, `src_configure`,
  `src_compile`, `src_install`, ...). Shared logic lives in eclasses pulled in with `inherit`.
- **Exherbo exheres:** a similar single file per version (`foo-1.2.exheres-0`) using the
  exheres-0 EAPI, with shared code in exlibs pulled in with `require`. Dependencies are written
  in one `DEPENDENCIES` block with `build:` / `run:` labels instead of separate variables.

## Repositories and syncing

- **Source Mage:** grimoires (`stable`, `test`, plus your own). The set of all grimoires is the
  codex. `scribe add` / `scribe update` manage them. A grimoire is split into sections
  (`utils/`, `x11/`, ...), as this repo's `grimoire/` is.
- **Gentoo:** one main tree (`::gentoo`) and optional overlays, managed with `eselect repository`
  and `repos.conf`.
- **Exherbo:** many small repositories (`::arbor` for the core, others per area or developer),
  added as you need them. Packages that exist upstream but aren't written yet can be tracked in
  the `unwritten` repository.

## Choosing optional features

- **Source Mage:** at `cast` time the spell asks yes/no and choice questions (optional
  dependencies, configure options). Answers are saved per spell under
  `/etc/sorcery/local/depends/` and reused next time. You can pre-seed them, which is what this
  installer does.
- **Gentoo:** USE flags, set globally in `/etc/portage/make.conf` and per package in
  `/etc/portage/package.use`, with defaults from the selected profile.
- **Exherbo:** options per package in `/etc/paludis/options.conf`, including suboptions such as
  `VIDEO_CARDS:` or `LINGUAS:` groups. There are no global flags in Gentoo's sense; settings go
  through package specs, though wildcards like `*/*` are allowed.

## Dependencies, slots and rebuilds

- Gentoo and Exherbo both support slots, so several versions of a library can be installed
  side by side. Source Mage has one version of a spell installed at a time.
- Gentoo and Exherbo resolve the whole dependency graph before building anything and show you
  the plan. Sorcery resolves dependencies while casting, asking the optional-dependency
  questions as it goes.
- After library upgrades: `cleanse --fix` (Source Mage), `@preserved-rebuild` (Gentoo),
  `cave fix-linkage` (Exherbo).

## Config file updates on upgrade

- **Gentoo:** protected files in `/etc` are written as `._cfg0000_*` copies and merged with
  `dispatch-conf` or `etc-update`.
- **Exherbo:** Paludis uses the same `._cfg` scheme, merged with tools such as `eclectic config`.
- **Source Mage:** sorcery detects config files you changed and asks at install time whether to
  keep yours, use the new one or merge them.

## Init, toolchain and layout

| | Source Mage | Gentoo | Exherbo |
|---|---|---|---|
| Default init | simpleinit-msb (`/etc/inittab`, init scripts), used by this installer | OpenRC; systemd profiles available | systemd |
| libc | glibc | glibc (musl profiles available) | glibc or musl |
| Layout | conventional FHS | conventional FHS | cross-friendly, binaries under `/usr/<triplet>/` (e.g. `/usr/x86_64-pc-linux-gnu/bin`) |
| Multilib / cross | not a focus | multilib profiles, crossdev | built in through the triplet layout |
| Binary packages | none official; sorcery can keep its own build caches for reinstalling | official binhost | pbins, binary packages produced and consumed by Paludis |
| Kernel | `linux` spell builds a kernel from your config | `gentoo-sources` / `gentoo-kernel(-bin)` packages | built by hand from upstream sources in the install guide |
| Upstream patching | minimal | more distro patches | minimal |
| Release model | rolling grimoires, occasional ISO/basesystem releases | rolling, weekly stage3 tarballs | rolling, stage tarballs |
| Size | small community | large community, extensive wiki and handbook | small core team, docs on exherbo.org |

## What this means for this installer

Source Mage asks its questions during the build, not in config files, so an unattended
install has to answer them ahead of time. `install.sh` does that by writing per-spell answer
files into `/etc/sorcery/local/depends/` (`linux.p`, `grub2.p`, `curl.p`, `mesa.p`), and with
`UNATTENDED=1` it feeds every remaining prompt from `/dev/null` so each one takes its default.
Spells the official grimoire lacks or gets wrong live in this repo's `grimoire/`, installed as
a local grimoire marked `CODEX_IS_LOCAL=yes`, so `scribe update` won't overwrite it. The Gentoo
equivalent would be a `package.use` file plus an overlay; on Exherbo, `options.conf` plus an
extra repository. The base tarball, chroot, kernel and bootloader steps line up with the
Gentoo and Exherbo installs one for one.
