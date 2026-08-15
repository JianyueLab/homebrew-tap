# JianyueLab Homebrew Tap

Homebrew tap for JianyueLab projects.

## Usage

```bash
brew tap JianyueLab/tap
```

Then install any of the casks/formulae below.

## Casks

### OneDocs (一文亦闻)

Cross-platform markdown and document reader.

```bash
brew install --cask JianyueLab/tap/onedocs
```

Upstream: <https://github.com/LYOfficial/OneDocs>

## Formulae

### EuroScope (on macOS, under Wine)

[EuroScope](https://www.euroscope.hu/) is the ATC radar client used on flight-sim
networks. It is a 32-bit Win32/MFC program with no macOS build, so this formula
installs a launcher that drives it under Wine — the EuroScope binary itself is
not patched in any way.

```bash
brew install JianyueLab/tap/euroscope
euroscope setup          # Wine + prefix + VC++ runtime + EuroScope
euroscope run            # or: euroscope app, for a double-clickable app
```

`brew install` downloads the official installer from euroscope.hu and checksums
it; `euroscope setup` is the step that actually builds the Wine environment.

Requires **Rosetta 2** on Apple Silicon (`softwareupdate --install-rosetta`),
because Wine's macOS build is x86_64. Point it at your sector packages with
`EUROSCOPE_SECTOR_DIR` and they are mapped to drive `S:` inside the prefix. Run
`euroscope` with no arguments for the full list of commands and variables.

Two pins inside the formula are deliberate and should not be casually bumped —
the comments in `Formula/euroscope.rb` spell out the failure modes:

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
