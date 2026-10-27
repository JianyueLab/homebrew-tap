# JianyueLab Homebrew Tap

Homebrew tap for JianyueLab projects.

## Usage

```bash
brew tap JianyueLab/tap
brew trust JianyueLab/tap
```

Then install any of the casks below. The `brew trust` step is not optional for
casks from a third-party tap: without it Homebrew refuses to load them with
`Run 'brew trust ...' to trust it`. Undo it with `brew untrust JianyueLab/tap`.

## Casks

### NotchNotch

MacBook Pro notch companion panel with media controls, drop shelf, clipboard history, calendar schedule reminders, and AI agent monitoring.

```bash
brew install --cask JianyueLab/tap/notchnotch
```

The published archive is Apple Silicon only. Intel hosts are not supported.

Upstream: <https://github.com/JianyueLab-Org/notch>

### OneDocs (一文亦闻)

Cross-platform markdown and document reader.

```bash
brew install --cask JianyueLab/tap/onedocs
```

Upstream: <https://github.com/LYOfficial/OneDocs>

### EuroScope (on macOS, under Wine)

[EuroScope](https://www.euroscope.hu/) is the ATC radar client used on flight-sim
networks. It is a 32-bit Win32/MFC program with no macOS build, so this cask
installs a launcher that drives it under Wine — the EuroScope binary itself is
not patched in any way.

```bash
brew install --cask JianyueLab/tap/euroscope
euroscope setup          # Wine + prefix + VC++ runtime + EuroScope + DXVK + EuroScope.app
euroscope run            # or open /Applications/EuroScope.app
```

`brew install` downloads the official installer from euroscope.hu and checksums
it; `euroscope setup` is the step that actually builds the Wine environment.

Requires **Rosetta 2** on Apple Silicon (`softwareupdate --install-rosetta`),
because Wine's macOS build is x86_64. Point it at your sector packages with
`EUROSCOPE_SECTOR_DIR` and they are mapped to drive `S:` inside the prefix. Run
`euroscope` with no arguments for the full list of commands and variables.

`EUROSCOPE_APP_DIR` is the complete bundle path, for example
`$HOME/Applications/EuroScope.app`, not an Applications directory.
The generated bundle records the prefix, cache directory and resolved Wine
binary used by `euroscope app`; Finder does not need those shell variables.
Uninstall removes that bundle only when its bundle identifier is EuroScope's.

`brew uninstall --cask euroscope` removes only the launcher. The Wine prefix,
the app bundle, the logs and the caches are built by `euroscope setup` rather
than by brew, so they are not cask artifacts — clear them with
`euroscope uninstall` or `brew zap --cask euroscope`.

**A cask rather than a formula, deliberately.** Homebrew runs
`fatal_build_from_source_checks` for any formula installed from source, and
`check_xcode_minimum_version` in that list is fatal whenever `/Applications/
Xcode.app` is older than the macOS release requires — even though this recipe
compiles nothing at all. Cask installs run none of those checks, so the cask
installs on machines where the formula could not.

**Only the current version can be a cask, and that is a licence limit rather
than an oversight.** euroscope.hu publishes exactly one release under
`/install/` — 3.2.13 today, plus a stray 3.2.3.2 — and every other version 404s.
A cask cannot exist without a public URL, and mirroring the installer to create
one is exactly what the EULA forbids: *"You may not redistribute the Software
Product in whole or part in any way without the express prior written approval
of the Developer."* This cask redistributes nothing; it downloads from the
official URL.

To run a version euroscope.hu no longer publishes, obtain the installer yourself
and point `EUROSCOPE_MSI` at it — this is supported, and the output labels
itself with the installer filename rather than the cask's version:

```bash
EUROSCOPE_MSI=~/Downloads/EuroScopeSetup.3.2.9.msi euroscope setup
```

Setup records the selected installer's SHA-256 in the prefix. Repeating setup
with the same installer preserves the installation. A different installer, or
an existing installation without a receipt, is refused before setup mutates
the prefix. Select a fresh `EUROSCOPE_PREFIX` and migrate your settings manually;
the old prefix is not deleted.

Bundle version metadata comes from the installed version receipt. A custom
installer with an unknown version omits `CFBundleShortVersionString`; its
filename is a display label, not a macOS version number. Rebuild the bundle
with `euroscope app` after selecting the intended prefix.

If a version does reappear upstream, a cask for it is this file with a new
`version`/`sha256` plus `conflicts_with` pointing at the other — every euroscope
cask shares one prefix, one app bundle and one `euroscope` command, so they are
alternatives rather than companions. The launcher script is inline in
`Casks/euroscope.rb`, since install steps cannot read files from the tap.

Two pins are deliberate and should not be casually bumped — the comments in
`Casks/euroscope.rb` spell out the failure modes:

- **Wine** is fetched straight from
  [Gcenx/macOS_Wine_builds](https://github.com/Gcenx/macOS_Wine_builds) rather
  than via `brew install --cask wine-stable`. Homebrew deprecated every WineHQ
  cask over notarization and **disables them on 2026-09-01**; fetching the same
  tarball the cask pointed at keeps working, needs no sudo, and skips the cask's
  `gstreamer-runtime` dependency, which EuroScope never uses.
- **DXVK** is Gcenx's `1.10.3 for_crossover` build, which routes Direct3D to
  Metal through MoltenVK. Upstream DXVK ≥ 2.0 will not start on MoltenVK, and a
  mismatched dxgi/d3d11 pair crashes on device creation.

## Updating a cask

Each cask has its own artifact source and checksum count. Set `VERSION` to
the upstream release being reviewed. Download into a project-local scratch
directory, then hash the exact asset served by the cask URL.

OneDocs uses **two** DMGs, one for each architecture:

```bash
VERSION=2.0.0
for ARCH in aarch64 x64; do
  FILE="OneDocs_${VERSION}_${ARCH}.dmg"
  curl --fail --location --output ".temp/$FILE" \
    "https://github.com/LYOfficial/OneDocs/releases/download/v${VERSION}/${FILE}"
  shasum -a 256 ".temp/$FILE"
done
```

NotchNotch uses **one** ZIP (arm64):

```bash
VERSION=27.1.7
FILE="NotchNotch-${VERSION}.zip"
curl --fail --location --output ".temp/$FILE" \
  "https://github.com/JianyueLab-Org/notch/releases/download/v${VERSION}/${FILE}"
shasum -a 256 ".temp/$FILE"
```

EuroScope uses **one** MSI from euroscope.hu, not a GitHub release:

```bash
VERSION=3.2.13
FILE="EuroScopeSetup.${VERSION}.msi"
curl --fail --location --output ".temp/$FILE" \
  "https://euroscope.hu/install/${FILE}"
shasum -a 256 ".temp/$FILE"
```

Create `.temp` before these commands and remove the downloaded files afterwards.
Update `version` and the corresponding `sha256` field(s). Review release notes,
the archive's actual architecture, and its installed version before release.

## Launcher regression checks

From the enclosing workspace, use an isolated project-local scratch directory:

```bash
TMPDIR="$PWD/.temp/audit-fixes-2026-10-26/Distribution" \
  ruby homebrew-tap/test/euroscope_test.rb
```

The check renders the embedded launcher and exercises filesystem behavior under
an isolated HOME. It does not install Wine or run a Windows application.
Linux can check Ruby/Bash and filesystem behavior, not Finder, macOS app
metadata interpretation, Rosetta, Swift builds, signing, or notarization.
Before release on macOS, check the generated plist with `plutil -lint`,
launch the bundle from Finder without shell environment overrides, and verify
Wine discovery and the selected prefix. Homebrew install, uninstall, and trust
changes require operator approval.

## Checking style

`brew style` only accepts casks inside a tap, so run it against a copy:

```bash
T="$(brew --repository)/Library/Taps/stylecheck/homebrew-tap"
mkdir -p "$T" && cp -R Casks "$T"/
brew style --cask "$T"/Casks/*.rb
rm -rf "$(dirname "$T")"
```
