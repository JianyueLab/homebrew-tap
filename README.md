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
euroscope setup          # Wine + prefix + VC++ runtime + EuroScope + DXVK
euroscope run            # or: euroscope app, for a double-clickable app
```

`brew install` downloads the official installer from euroscope.hu and checksums
it; `euroscope setup` is the step that actually builds the Wine environment.

Requires **Rosetta 2** on Apple Silicon (`softwareupdate --install-rosetta`),
because Wine's macOS build is x86_64. Point it at your sector packages with
`EUROSCOPE_SECTOR_DIR` and they are mapped to drive `S:` inside the prefix. Run
`euroscope` with no arguments for the full list of commands and variables.

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

After a new upstream release, bump `version` and update both `sha256` values in `Casks/<name>.rb`. Get the digests from the GitHub release page or with:

```bash
gh release view <tag> -R <owner>/<repo> --json assets \
  --jq '.assets[] | select(.name | test("dmg$")) | "\(.name)  \(.digest)"'
```

## Checking style

`brew style` only accepts casks inside a tap, so run it against a copy:

```bash
T="$(brew --repository)/Library/Taps/stylecheck/homebrew-tap"
mkdir -p "$T" && cp -R Casks "$T"/
brew style --cask "$T"/Casks/*.rb
rm -rf "$(dirname "$T")"
```
