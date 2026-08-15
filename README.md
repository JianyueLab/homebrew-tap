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

**Multiple versions are mutually exclusive.** Every euroscope cask shares one
prefix, one app bundle and one `euroscope` command, so they declare
`conflicts_with` each other: install one, or the other, not both. The
implementation is shared — `libexec/euroscope.sh`, substituted per cask at
install time. **Edit that file, never a cask.**

Two pins are deliberate and should not be casually bumped — the comments in
`Casks/euroscope.rb` and `libexec/euroscope.sh` spell out the failure modes:

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
