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
  other *(SM)*. Its goals are covered under [Philosophy](#philosophy).
- **Gentoo** is the largest of the three, with one big main tree and Portage, written in Python.
  It offers official binary packages too.
- **Exherbo** was started by former Gentoo developers. It keeps the ebuild-like shape but splits
  the package tree into many small repositories, with a small core team. Its package manager is
  Paludis (C++), and it treats source and binary packages on equal terms.

## Philosophy

Each project's view in its own words, quoted from its own pages:
Gentoo's [philosophy](https://www.gentoo.org/get-started/philosophy/), [Social Contract](https://www.gentoo.org/get-started/philosophy/social-contract.html), [About](https://www.gentoo.org/get-started/about/) and [Council](https://wiki.gentoo.org/wiki/Project:Council) pages;
Exherbo's [homepage](https://exherbo.org/) and [expectations](https://exherbo.org/docs/expectations.html); Source Mage's [Intro](https://sourcemage.org/Intro),
[Social Contract](https://sourcemage.org/Social%20Contract), [History](https://sourcemage.org/History) and [Comparison with Gentoo](https://sourcemage.org/Comparison%20with%20Gentoo).

### Core goal and target user

- **Source Mage** is "founded on the principle of returning control back to System
  Administrators", and is aimed at "System administrators, power-users and others who really want
  control over their systems and want to understand better how 'things' work" ([Intro](https://sourcemage.org/Intro)).
  It calls itself "the distribution for LFS users who are willing to let a package manager at
  least automate the 'download and `./configure && make && make install`' part of the process,
  but not willing to lose any other control" ([Comparison](https://sourcemage.org/Comparison%20with%20Gentoo)).
- **Gentoo**: "Every user has work they need to do. The goal of Gentoo is to design tools and
  systems that allow a user to do that work as pleasantly and efficiently as possible, as they see
  fit." Daniel Robbins' summary: "The tool serves the user rather than the user serving the
  tool" ([philosophy](https://www.gentoo.org/get-started/philosophy/)). Its near-unlimited adaptability is why "we call Gentoo a
  metadistribution" ([About](https://www.gentoo.org/get-started/about/)).
- **Exherbo** "aims to be a stable and flexible distribution for developers, tinkerers and people
  who need their distribution to help them be productive", and states "The target users know what
  they are doing" ([homepage](https://exherbo.org/)).

### User control and defaults

- **Source Mage**: "You are the administrator and you know how best to deploy and configure
  software. We handle the installation." Packages stay "as close to upstream vendor's vision as
  possible" ([Intro](https://sourcemage.org/Intro)). Its stated goal is "a 100% free source-based GNU/Linux distro that
  allows users the maximum amount of freedom and choice possible" ([History](https://sourcemage.org/History)).
- **Gentoo**: "If the tool forces the user to do things a particular way, then the tool is
  working against, rather than for, the user" ([philosophy](https://www.gentoo.org/get-started/philosophy/)). Source Mage describes
  Gentoo's approach as "sensible defaults" ([Comparison](https://sourcemage.org/Comparison%20with%20Gentoo)); see
  [Defaults and patching](#defaults-and-patching).
- **Exherbo**: "Flexibility where it makes sense to provide flexibility", and "All design goals
  must be phrased in such a way that it is hard to use them as slogans to justify stupidity"
  ([homepage](https://exherbo.org/)).

### Interactivity vs up-front configuration

- **Source Mage** asks: "The default behaviour is to ask the admin during install what their
  choice is for every option a package supports, then store the answer" ([Comparison](https://sourcemage.org/Comparison%20with%20Gentoo)).
- **Gentoo** keeps out of the way: a good tool "does not interfere and make its presence known,
  nor does it force you to interact with it when you don't want it to" ([philosophy](https://www.gentoo.org/get-started/philosophy/)).
  Its settings are global with per-package overrides ([Comparison](https://sourcemage.org/Comparison%20with%20Gentoo)).
- **Exherbo** rules interactivity out: "No interactivity requirement. Controllable, repeatable
  behaviour with up-front configuration" ([homepage](https://exherbo.org/)).

### Upstream and patching

- **Source Mage** promises to "feed back bug-fixes, improvements, user requests, etc. to the
  'upstream' authors" ([Social Contract](https://sourcemage.org/Social%20Contract)) and patches only with the user's consent, the
  default answer being "no" ([Comparison](https://sourcemage.org/Comparison%20with%20Gentoo)).
- **Gentoo** will "submit bug-fixes, improvements, user requests, etc. to the 'upstream' authors"
  and "clearly document our contributions to Gentoo as well as any improvements or changes we make
  to external sources used by Gentoo (whether in the form of patches, 'sed tweaks' or some other
  form)" ([Social Contract](https://www.gentoo.org/get-started/philosophy/social-contract.html)).
- **Exherbo** "Uses a couple of bits of code, and some ideas, from other open source projects,
  but the majority of code is original, not forked" ([homepage](https://exherbo.org/)).

### Centralisation

- **Exherbo**: "No over-centralisation. Only widely used packages are to be in main repositories,
  and make the tools good enough to deal with lots of small third party repositories"
  ([homepage](https://exherbo.org/)).
- **Gentoo** syncs one main ebuild repository, with "more than 19,000 unique packages"
  ([About](https://www.gentoo.org/get-started/about/)).
- **Source Mage** supports several package trees side by side "by default", which it calls
  "arguably much more straightforward" than Gentoo's overlays ([Comparison](https://sourcemage.org/Comparison%20with%20Gentoo)).

### Stability vs freedom to break things

- **Exherbo**: "We need the freedom to break things when necessary", because "Some of our ideas
  differ greatly from other distributions and it's much easier if we don't have to fight legacy
  code and ideas"; also "Be able to deliver features that other distributions consider too
  ambitious" ([homepage](https://exherbo.org/)).
- **Source Mage** releases the stable grimoire "QA tested as a unit" and keeps older stable trees
  installable alongside ([Comparison](https://sourcemage.org/Comparison%20with%20Gentoo)).
- **Gentoo** keeps several versions in one tree and masks those not expected to update cleanly
  (as described in [Comparison](https://sourcemage.org/Comparison%20with%20Gentoo)).

### Free software and licensing

- **Source Mage**: "Source Mage will remain 100% free"; its own software is GPL, included
  software GPL-compatible, docs under the GFDL, and "we will never make the core system depend on
  an item of non-free software". But "We will not limit user choice to our free software
  standards": each spell's `LICENSE` field and the sorcery spell filter let users decide
  ([Social Contract](https://sourcemage.org/Social%20Contract)). Non-free packages live in the unofficial "z-rejected" grimoire
  ([Intro](https://sourcemage.org/Intro)).
- **Gentoo**: "Gentoo is and will remain free software", released under GPL-2 or later or
  CC-BY-SA 2.0 or later, and "Gentoo will never depend upon a piece of software or metadata"
  that doesn't fulfil the Free Software Definition or the Definition of Free Cultural Works. It
  also requires that "the operating system should be able to build itself from scratch"
  ([Social Contract](https://www.gentoo.org/get-started/philosophy/social-contract.html)).
- **Exherbo**: no licensing statement on the pages fetched.

### Transparency

- **Gentoo**: "We will not hide problems"; the bug database is open "at all times", with
  exceptions for security embargoes, community relations, or the Council's discretion
  ([Social Contract](https://www.gentoo.org/get-started/philosophy/social-contract.html)).
- **Source Mage**: "We will keep our entire bug-report database open for public view at all
  times" ([Social Contract](https://sourcemage.org/Social%20Contract)). Both contracts say they are derived from Debian's.

### Governance

- **Gentoo**: "The elected Gentoo Council decides on global issues and policies that affect
  multiple projects in Gentoo." Members "are elected for a year and must hold monthly public
  meetings", the Council hears appeals, and the structure "was created via GLEP 39"
  ([Council](https://wiki.gentoo.org/wiki/Project:Council)). The About page puts it at 7 members and "around 250 developers"
  ([About](https://www.gentoo.org/get-started/about/)).
- **Source Mage** and **Exherbo**: no governance page found. Source Mage's History notes the
  project name was chosen "after a vote" ([History](https://sourcemage.org/History)).

### Contribution model

- **Exherbo**: "For developers - we expect users to take part in the development", and "using
  Exherbo is an active commitment. We fully expect you to help with development or other parts
  of the project" ([expectations](https://exherbo.org/docs/expectations.html)). In its first year, contributions came "from over 70
  different people" ([homepage](https://exherbo.org/)).
- **Source Mage**: "Working on this project is about FUN!", and if things aren't happening fast
  enough "by all means you are welcome to join in" ([Social Contract](https://sourcemage.org/Social%20Contract)). Patches are guided
  "through peer review and compliance with our core principles and policies" ([Intro](https://sourcemage.org/Intro)),
  and "we typically will let anyone who can write a patch and wants to try their hand become a
  developer" ([Comparison](https://sourcemage.org/Comparison%20with%20Gentoo)).
- **Gentoo**: comments on the Social Contract go to the gentoo-dev mailing list
  ([Social Contract](https://www.gentoo.org/get-started/philosophy/social-contract.html)).

See also [Community](#community) for how each describes its users and channels.

### Honesty about weaknesses

- **Source Mage** has a "Where Gentoo wins" list: binary packages, number of packages,
  architectures and docs ("we hurt a lot here") ([Comparison](https://sourcemage.org/Comparison%20with%20Gentoo)).
- **Exherbo** warns "Exherbo is not a system where we document everything so you'll need a basic
  understanding of how Linux systems work" ([expectations](https://exherbo.org/docs/expectations.html)).
- **Gentoo**: no such list on the pages fetched, though "We will not hide problems" is in its
  Social Contract.

### Summary

| | Source Mage | Gentoo | Exherbo |
|---|---|---|---|
| Core idea | control back to the administrator | the tool serves the user | productive tools for developers |
| Target user | sysadmins, power users | anyone, any use (metadistribution) | users who know what they're doing |
| Choosing features | asked per package, remembered | global settings, per-package overrides | up front, no interactivity |
| Upstream | upstream defaults, patches opt-in | patches documented, fixes sent upstream | mostly original code |
| Repositories | several trees side by side | one main repository | many small repositories |
| Stability | QA'd stable grimoire releases | masks within one tree | freedom to break things |
| Free software | 100% free core, non-free allowed separately | free software, self-hosting | no statement found |
| Governance | no page found | elected 7-member Council | no page found |
| Contributing | anyone who writes patches | mailing lists, developers | expected of every user |

**For this installer:** Source Mage's ask-every-time model is the opposite of Exherbo's "No
interactivity requirement". `install.sh` bridges the two by pre-seeding answers under
`/etc/sorcery/local/depends/` and, with `UNATTENDED=1`, taking defaults for everything else.
That gives a repeatable, up-front install while keeping Source Mage's upstream-default spells.

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

## Community

Each project describes its community in its own words, and the three read very differently.
Quotes are from each project's own pages. Source Mage's page contrasts itself with "things said
about the Gentoo community"; that is their claim, and plenty of Gentoo users (this repo's
author included) would disagree.

**Source Mage: welcoming to people who want to learn.** From
[Comparison with Gentoo](https://sourcemage.org/Comparison%20with%20Gentoo):

> People who are willing to RTFM and are interested in learning things will find the most value
> in talking to us or using our software, but we usually try to make everyone reasonably welcome
> and assume anyone is able to learn more than they know now.

They also say "anyone who can write a patch and wants to try their hand" can become a developer.
And they openly admit where Gentoo leads: binary packages, package count, architectures and docs.
They point out that a missing autotools package can be generated from its tarball URL with Quill.

**Gentoo: rules of conduct, and promises from the project.** The
[Code of Conduct](https://wiki.gentoo.org/wiki/Project:Council/Code_of_conduct) asks you to
"Be courteous. Though respect is earned, it must start somewhere." It also asks you to give
accurate information, disagree respectfully, write clearly for a worldwide audience, and "If you
screw up, take responsibility for your actions." Flaming, trolling, stirring up drama and
repeatedly spreading misinformation can lead to suspension. That is handled by the Community
Relations team, and you can appeal to the Council. The
[Social Contract](https://www.gentoo.org/get-started/philosophy/social-contract.html) lists the
project's promises: it stays free software, it gives fixes back upstream, and "We will not hide
problems", so the bug tracker stays public. The
[philosophy page](https://www.gentoo.org/get-started/philosophy/) sums up the attitude: "The tool
serves the user rather than the user serving the tool."

**Exherbo: you are expected to take part.** From
[What we expect from developers](https://exherbo.org/docs/expectations.html):

> First of all you need to understand that using Exherbo is an active commitment. We fully expect
> you to help with development or other parts of the project.

You are expected to read the docs and man pages first, and to follow advice exactly, so a full
build log means the full build log. Use `#exherbo` on Libera.Chat, speak up about problems, and
give back. The [goals on exherbo.org](https://exherbo.org/) set the tone: "All design goals must
be phrased in such a way that it is hard to use them as slogans to justify stupidity" and "The
target users know what they are doing". They also include "No interactivity requirement.
Controllable, repeatable behaviour with up-front configuration", which is the opposite of Source
Mage asking questions at `cast` time.

| | Source Mage | Gentoo | Exherbo |
|---|---|---|---|
| Stated stance | friendly, assumes you can learn | courteous, respectful, accountable | committed contributors who read first |
| What it asks of you | RTFM, curiosity | follow the Code of Conduct | help develop, read docs, use IRC, give back |
| Becoming a developer | anyone who can write a patch | via the project's developer process | expected of every user |
| Main channels | e-mail, mailing lists, IRC, forums ([Contact](https://sourcemage.org/Contact)) | forums, IRC, mailing lists, Bugzilla ([Get involved](https://www.gentoo.org/get-involved/), [Support](https://www.gentoo.org/support/)) | `#exherbo` on Libera.Chat (primary), exherbo-dev mailing list ([expectations](https://exherbo.org/docs/expectations.html)) |
| Enforcement | not described on that page | Community Relations, appeals to the Council | not described on that page |

## Free software and libre kernels

This builds on [Free software and licensing](#free-software-and-licensing) above. Sources are
each project's own pages, package trees and the FSF/GNU pages. Where no official page was
found, it says so.

### Stated stance and licence handling

- **Source Mage**: the [Social Contract](https://sourcemage.org/Social%20Contract) says "Source
  Mage will remain 100% free" and "we will never make the core system depend on an item of
  non-free software", but "We will not limit user choice to our free software standards". Each
  spell carries a `LICENSE` field, and sorcery's spell filter lets you refuse spells by licence.
  The [Docs](https://sourcemage.org/Docs) index describes the separate Z-rejected grimoire as
  the place to "use non-free blobs in your free system if you need to".
- **Gentoo**: the [Social Contract](https://www.gentoo.org/get-started/philosophy/social-contract.html)
  says Gentoo "will never depend upon a piece of software or metadata" that isn't free, but the
  tree also packages non-free software. Every ebuild has a `LICENSE`, and Portage only installs
  what `ACCEPT_LICENSE` allows. The base profile default is `ACCEPT_LICENSE="-* @FREE"`
  ([profiles/base/make.defaults](https://gitweb.gentoo.org/repo/gentoo.git/plain/profiles/base/make.defaults)).
  The groups are defined in
  [profiles/license_groups](https://gitweb.gentoo.org/repo/gentoo.git/plain/profiles/license_groups):
  `@FREE` is `@FREE-SOFTWARE @FREE-DOCUMENTS`, and `@BINARY-REDISTRIBUTABLE` is `@FREE` plus
  licences such as `linux-fw-redistributable`, `intel-ucode` and `no-source-code`.
- **Exherbo**: no page found with a free-software policy or social contract. Packages list their
  licences in `LICENCES`. Paludis reads accepted licences from `licences.conf`, using the same
  `-*`, `@GROUP` and `-licence` tokens, and its docs say "Most users will only want" `*/* *`
  ([Paludis: licences.conf](https://paludis.exherbo.org/configuration/licenses.html)).

### Firmware and microcode

- **Source Mage**: `kernels/linux-firmware` (from kernel.org's linux-firmware git) and
  `kernels/microcode_ctl` are in the main grimoire
  ([grimoire](https://codeberg.org/sourcemage/grimoire/src/branch/master/kernels)). Both
  `DETAILS` files set `LICENSE[0]=GPL`, even though linux-firmware is mostly binary blobs. That
  means a licence-based spell filter would not catch them.
- **Gentoo**: `sys-kernel/linux-firmware` has a `+redistributable` USE flag. When it is set,
  the package's `LICENSE` adds `linux-fw-redistributable`. With `-redistributable`, the ebuild
  removes the non-redistributable files
  ([ebuild](https://gitweb.gentoo.org/repo/gentoo.git/tree/sys-kernel/linux-firmware),
  [package page](https://packages.gentoo.org/packages/sys-kernel/linux-firmware)).
  `sys-firmware/intel-microcode` is under `intel-ucode`
  ([package page](https://packages.gentoo.org/packages/sys-firmware/intel-microcode)). Neither
  licence is in `@FREE`, so the default `ACCEPT_LICENSE` refuses both until you accept them,
  for example with `@BINARY-REDISTRIBUTABLE`. The
  [Going 100% Libre](https://wiki.gentoo.org/wiki/Going_100%25_Libre_with_Gentoo) page says linux-firmware "by default ... includes non-free firmware and
  thus will not install if `ACCEPT_LICENSE="@FREE -*"` is set". It recommends
  `sys-kernel/linux-firmware -redistributable` in `/etc/portage/package.use/`, which it says "is
  intended to exclude firmware that is non-free or has redistribution restrictions". The same page
  recommends `ACCEPT_LICENSE="-* @FREE"` in `make.conf`, optionally `-Artistic` and `-NPSL-0.95`,
  and the `FSF-APPROVED` group for stricter FSF alignment. It also suggests
  `USE="eme-free -proprietary-codecs -telemetry"`. Beyond the OS, it discusses free boot
  firmware (GNU Boot, Canoeboot) to replace Intel ME/AMD PSP firmware.
- **Exherbo**: `firmware/linux-firmware` and `firmware/intel-microcode` are in the official
  `hardware` repository, together with other blobs such as `b43-firmware` and `ipw2200-firmware`
  ([summer: hardware](https://summer.exherbo.org/repositories/hardware/index.html)).
  linux-firmware lists each vendor licence in `LICENCES`
  ([exlib](https://gitlab.exherbo.org/exherbo/hardware/-/blob/master/packages/firmware/linux-firmware/linux-firmware.exlib)),
  and intel-microcode uses `LICENCES="intel-ucode"`. The install guide says to
  `cave resolve linux-firmware` if you need it, for example for an Intel wireless card
  ([install guide](https://exherbo.org/docs/install-guide.html)).

### Libre kernels

[GNU Linux-libre](https://www.fsfla.org/ikiwiki/selibre/linux-libre/) is the FSFLA's
deblobbed Linux. The FSF's free distros all ship it or an equivalent.

- **Source Mage**: no linux-libre spell. The grimoire's `kernels/` section has `linux`, but no
  libre or deblob spell, and no deblob files in the `linux` spell
  ([kernels/](https://codeberg.org/sourcemage/grimoire/src/branch/master/kernels)).
- **Gentoo**: no `linux-libre` package in the official tree
  ([packages.gentoo.org search](https://packages.gentoo.org/packages/search?q=linux-libre)), and
  none of the registered overlays is named for it
  ([repositories.xml](https://api.gentoo.org/overlays/repositories.xml)). The
  [gpo.zugaina.org](https://gpo.zugaina.org/Search?search=linux-libre) overlay index search found
  no kernel package either. But there is a documented libre route. The Gentoo wiki's
  [Going 100% Libre with Gentoo](https://wiki.gentoo.org/wiki/Going_100%25_Libre_with_Gentoo) says Gentoo "can be configured to meet the GNU Free System
  Distribution Guidelines (GNU FSDG) with specific modifications". For the kernel it says "a
  deblobbed kernel, such as Linux-libre, is required" and points to
  [Kernel/Deblobbing](https://wiki.gentoo.org/wiki/Kernel/Deblobbing). That page gives two routes:
  - **`sys-kernel/rt-sources` with `USE=deblob`**: "sources will be automatically deblobed after
    being emerged". This uses
    [kernel-2.eclass](https://gitweb.gentoo.org/repo/gentoo.git/plain/eclass/kernel-2.eclass)'s
    built-in deblobbing ("deblob for libre support"), which fetches the FSFLA `deblob-X.Y` and
    `deblob-check` scripts and runs them during the build. In a checkout of the tree today
    (2026-11-08), all eight `rt-sources` ebuilds set `K_DEBLOB_AVAILABLE="1"`, and it's the only
    kernel package that does
    ([rt-sources](https://packages.gentoo.org/packages/sys-kernel/rt-sources)).
    `raspberrypi-sources` sets it to `0`, and the current
    [gentoo-sources ebuild](https://gitweb.gentoo.org/repo/gentoo.git/tree/sys-kernel/gentoo-sources)
    doesn't set it, so there's no `deblob` flag there.
  - **gentoo-sources (or any other sources), by hand**: emerge the sources, then download
    `deblob-<main>`, `deblob-check` and their `.sign` files from the Linux-libre releases server.
    Verify them with gpg, and run `./deblob-$main` in `/usr/src/linux`. The resulting kernel
    gets a `-gnu` suffix (for example `6.8.1-gentoo-gnu`). The page notes that since 4.14 the
    firmware tree is no longer in the kernel, so deblobbing is "unnecessary for new kernel
    versions", but the Linux-libre patches also remove things such as firmware loaders. It
    also warns that "devices that exclusively support proprietary firmware cannot be used",
    which it says generally includes "all new Intel wireless cards".
- **Exherbo**: no linux-libre package. Exherbo has no kernel package at all; `sys-kernel` only
  holds `caitsith`, `dkms`, `linux-headers` and `lux`
  ([summer: sys-kernel](https://summer.exherbo.org/packages/sys-kernel/index.html)). The install
  guide has you download and build a kernel from kernel.org yourself
  ([install guide](https://exherbo.org/docs/install-guide.html)). A search of summer's
  repository listings found no libre kernel in any of them.

**Deblobbing yourself** works the same way on all three. Each Linux-libre release publishes
`deblob-<major.minor>` and `deblob-check` (with `.sign` signatures), for example
[releases/7.3.3-gnu/](https://linux-libre.fsfla.org/pub/linux-libre/releases/7.3.3-gnu/).
You run the matching `deblob-X.Y` in a vanilla kernel.org tree of that version, or you download
the already-cleaned `linux-libre` tarball from the same directory and build that. The project
also keeps scripts and tags in `git://linux-libre.fsfla.org/releases.git`
([project page](https://www.fsfla.org/ikiwiki/selibre/linux-libre/)).

### FSF free-distro list

None of the three is on the FSF's
[free GNU/Linux distributions](https://www.gnu.org/distros/free-distros.html) list. That page
does not mention Gentoo, Exherbo or Source Mage. On
[Why we don't endorse some common distros](https://www.gnu.org/distros/common-distros.html),
only Gentoo is named: "Gentoo includes installation recipes for a number of nonfree programs in
its primary package system." Exherbo and Source Mage do not appear there.

### What a libre build needs with these installers

- **This repo (`install.sh`)**: the kernel is the grimoire's `linux` spell, cast in the core
  phase (`SPELLS_CORE`). When run unattended, it writes `/etc/sorcery/local/depends/linux.p`
  with the newest `LATEST_<n>` series from `kernels/linux/latest.defaults`, plus that series'
  maintenance patches, and builds from `make defconfig` (or `kernel/vm.config` for
  `PROFILE=vm`). No spell deblobs it, so a libre kernel means one of two things: add a
  `linux-libre` spell to this repo's local `grimoire/kernels/` and cast it instead of `linux`,
  or run `deblob-X.Y` on the source before the build. Firmware is a separate list:
  `SPELLS_MAC` (`linux-firmware microcode_ctl … broadcom-wl`) is only added for
  `PROFILE=macbookair`, and the VM profile casts no firmware. `broadcom-wl` (the proprietary
  Broadcom driver, in this repo's `grimoire/`) is what the MacBook Air's Wi-Fi uses. Dropping it
  would leave that card without a driver unless you add another card.
- **[legenddots Gentoo installer](https://github.com/legendarymsr/legenddots/blob/master/gentoo/install.sh)**:
  emerges `gentoo-sources`, `linux-firmware` and `intel-microcode`. To swap the kernel, you'd
  switch to `rt-sources` with `USE=deblob`, or follow the wiki's manual deblob steps on
  gentoo-sources. Leave `intel-microcode` out, set `linux-firmware -redistributable` (or drop it),
  and keep `ACCEPT_LICENSE="-* @FREE"`
  ([Going 100% Libre](https://wiki.gentoo.org/wiki/Going_100%25_Libre_with_Gentoo)).
- **[legenddots Exherbo setup](https://github.com/legendarymsr/legenddots/blob/master/exherbo/exherbo-setup.sh)**:
  already builds the kernel from kernel.org, so you'd fetch the linux-libre tarball (or run
  `deblob-X.Y`) at that step and skip `cave resolve linux-firmware`.

### Summary

| | Source Mage | Gentoo | Exherbo |
|---|---|---|---|
| Free-software policy | Social Contract: 100% free core, user choice | Social Contract: free, but non-free in tree; wiki guide to an FSDG setup | no page found |
| Licence gating | per-spell `LICENSE` + spell filter | `ACCEPT_LICENSE`, default `-* @FREE` | `LICENCES` + Paludis `licences.conf` |
| linux-firmware / microcode | main grimoire, marked `GPL` | in tree, needs non-`@FREE` licences | official `hardware` repo |
| Official libre kernel package | none | no linux-libre package, but `rt-sources` has `USE=deblob` (only kernel that enables it) | none (no kernel package at all) |
| Libre kernel in overlays/repos | none found | none found | none found |
| On FSF free list | no | no (named on common-distros page) | no |
| DIY route | custom spell or `deblob-X.Y` | `rt-sources` + `deblob`, or manual `deblob-X.Y` on gentoo-sources ([wiki](https://wiki.gentoo.org/wiki/Kernel/Deblobbing)) | linux-libre tarball at the kernel step |

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
