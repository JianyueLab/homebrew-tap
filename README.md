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

## Updating a cask

After a new upstream release, bump `version` and update both `sha256` values in `Casks/<name>.rb`. Get the digests from the GitHub release page or with:

```bash
gh release view <tag> -R <owner>/<repo> --json assets \
  --jq '.assets[] | select(.name | test("dmg$")) | "\(.name)  \(.digest)"'
```
