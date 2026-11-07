# Source Mage vs Gentoo vs Exherbo

> "Linux so advanced, it may as well be magic." (Source Mage's slogan)

Source Mage says plainly that it is not a Gentoo clone: the similarities "tend to end beyond the
abstraction of 'download and compile from source'". Its own write-up is
[Comparison with Gentoo](https://sourcemage.org/Comparison%20with%20Gentoo); the Source Mage
points below that come from it are marked *(SM)*.

All three are source-based distributions whose package recipes are bash. This page goes
through where they agree and where they differ, and what that means for this installer.

## History and goals

- **Source Mage** descends from Sorcerer GNU/Linux (Kyle Sallee, 2001). In 2002 the Sorcerer
  GNU/Linux team kept developing after Sallee took his project offline and relicensed it, and
  at his request renamed theirs Source Mage. Source Mage notes that Sorcerer started around
  2000, about the same time as Gentoo, and that the two never had anything to do with each
  other *(SM)*. Its aim is to stay close to upstream: a spell
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
- Both are for people who want "no more and no less" than they asked for and are used to
  reading `./configure --help` before building *(SM)*.
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
| Update everything | `sorcery system-update` (or `sorcery queue` then `cast --queue`) | `emerge -auDN @world` | `cave resolve -x world -c` |
| Search | `gaze search foo` | `emerge --search foo` | `cave search foo` |
| Show package info | `gaze what foo` | `emerge -pv foo` / `equery meta foo` | `cave show foo` |
| Which package owns a file | `gaze from /path` | `equery belongs /path` | `cave owner /path` |
| Fix broken linking | `cleanse --fix` | `emerge @preserved-rebuild` (`revdep-rebuild` is older) | `cave fix-linkage` |

`sorcery` with no arguments opens a menu for grimoires, spells and system features. Sorcery
has 13 commands: alter, cabal, cast, cleanse, confmeld, delve, dispel, gaze, resurrect,
scribbler, scribe, sorcery and summon. All of them are bash, using only coreutils, sed, grep
and the like; keeping core dependencies minimal is a stated design goal *(SM)*. Portage is
Python and Paludis is C++.

## Recipe format

- **Source Mage spell:** a directory with one file per step. `DETAILS` holds name, version,
  source URL, hash and description; `DEPENDS` declares dependencies and optional ones with
  `depends` / `optional_depends`; then optional `CONFIGURE` (ask questions), `PRE_BUILD`, `BUILD`,
  `INSTALL` and others. Any step left out falls back to a default (for example
  `./configure && make && make install`). This repo's `grimoire/` has real examples.
- **Gentoo ebuild:** one file per version (`foo-1.2.ebuild`) with variables (`SRC_URI`, `IUSE`,
  `DEPEND`, `RDEPEND`, `SLOT`, `KEYWORDS`) and phase functions (`src_prepare`, `src_configure`,
  `src_compile`, `src_install`, ...). Shared logic lives in eclasses pulled in with `inherit`.
- **Exherbo exheres:** a similar single file per version (`foo-1.2.exheres-0`), with shared
  code in exlibs instead of eclasses.

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

- **Source Mage:** per package and per option, not global *(SM)*. At `cast` time the spell asks
  about every option it supports, e.g. "Do you want to use GTK?", defaulting to yes if GTK is
  already installed and no otherwise, and stores the answer for the next upgrade or rebuild.
  You can set a global default (like a global USE flag), but you are still asked and can
  override it. You can also pass extra `./configure` flags the spell doesn't expose, and they
  are remembered too *(SM)*. Answers live under `/etc/sorcery/local/depends/`, which is how
  this installer pre-seeds them.
- **Gentoo:** USE flags, set globally in `/etc/portage/make.conf` and per package in
  `/etc/portage/package.use`, with defaults from the selected profile. Options without a USE
  flag mean editing the ebuild *(SM)*.
- **Exherbo:** options per package in `/etc/paludis/options.conf`, using package specs, with
  `*/*` for defaults across all packages.

## Defaults and patching

- **Gentoo** follows "sensible defaults": its own default configs and third-party feature
  patches *(SM)*.
- **Source Mage** guarantees upstream defaults: accept every default and you get exactly what
  upstream's own install instructions give. Feature patches and custom configs are offered but
  never applied without asking, and the default answer is always "no". Exceptions are FHS
  install paths, patches needed for your dependency choices, and security or build fixes,
  taken from upstream where possible *(SM)*. Source Mage calls itself "an open wrapper around
  LFS" *(SM)*.
- **Exherbo** also aims to stay close to upstream.

## Versions, masks and QA

- **Gentoo** carries several versions of a package in one tree, some masked until they're
  known to update cleanly *(SM)*.
- **Source Mage** ships the latest upstream "current recommended release" by default, with
  regular QA-tested releases of the stable grimoire as a unit. For older versions you install
  an earlier stable grimoire alongside the current one, so you get the package with the
  dependencies it was tested with. Spells can also offer devel/git branches *(SM)*.

## Dependencies, slots and rebuilds

- All three have slots for side-by-side versions; in sorcery they are declared by the spell
  (`gaze slots`), and a spell without one has the single default slot `0`.
- Gentoo and Exherbo resolve the whole dependency graph before building anything and show you
  the plan. Sorcery resolves dependencies while casting, asking the optional-dependency
  questions as it goes.
- Sorcery prunes no-longer-needed dependencies on uninstall *(SM)*.
- After library upgrades: `cleanse --fix` (Source Mage), `@preserved-rebuild` (Gentoo),
  `cave fix-linkage` (Exherbo). Source Mage describes cleanse as "`fsck` for the installed
  packages" *(SM)*.
- Sorcery downloads sources in the background and starts compiling as soon as the needed ones
  arrive *(SM)*.

## Config file updates on upgrade

- **Gentoo:** protected files in `/etc` are written as `._cfg0000_*` copies and merged with
  `dispatch-conf` or `etc-update`.
- **Source Mage:** `cast` does not overwrite config files with newer versions. It stages them in
  `/var/state/sorcery/staged_configs`, and `confmeld` settles the simple cases and asks about the
  rest: keep the old file or install the new one (each optionally with a backup), with a diff
  on request.

## Init, toolchain and layout

| | Source Mage | Gentoo | Exherbo |
|---|---|---|---|
| Default init | simpleinit-msb (`/etc/inittab`, init scripts), used by this installer | OpenRC; systemd profiles available | systemd |
| libc | glibc | glibc (musl profiles available) | glibc or musl |
| Layout | conventional FHS | conventional FHS | cross-friendly, binaries under `/usr/<triplet>/` (e.g. `/usr/x86_64-pc-linux-gnu/bin`) |
| Multilib / cross | | multilib profiles, crossdev | built in through the triplet layout |
| Binary packages | a checkbox builds a cache of everything cast, used to restore or seed systems; no binary host download *(SM)* | official binhost | Paludis handles binary packages on equal terms with source ones |
| Kernel | `linux` spell builds a kernel from your config | `gentoo-sources` / `gentoo-kernel(-bin)` packages | install guide builds it from kernel.org sources |
| Release model | rolling grimoires, occasional ISO/basesystem releases | rolling, weekly stage3 tarballs | rolling, stage tarballs |
| Size | small; fewer packages and architectures than Gentoo, docs thinner, by its own account *(SM)* | large, famous docs | small core team (~20) using many small repos |
| Build helpers | one-switch distcc, ccache, tmpfs and screen builds *(SM)* | via `FEATURES` | |
| Source checks | every download checked against a GPG signature or strong hash *(SM)* | Manifest hashes | |

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
