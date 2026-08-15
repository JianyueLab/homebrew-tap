class Euroscope < Formula
  desc "ATC radar client for flight-sim networks, running on macOS under Wine"
  homepage "https://www.euroscope.hu/"
  url "https://euroscope.hu/install/EuroScopeSetup.3.2.13.msi", using: :nounzip
  version "3.2.13"
  sha256 "ba1fe4050ec8f8172567e9022b2c5da8198efa1d02986dfcd2f326bf2cd695c0"
  # EuroScope ships an EULA inside the installer rather than a SPDX licence.
  license :cannot_represent

  # A bare symbol means "this version or newer" for a formula; the ">= :ventura"
  # string form is cask syntax and is rejected here.
  depends_on macos: :ventura

  def install
    # The MSI is the upstream installer, downloaded and checksummed by brew and
    # then handed to Wine's msiexec. Nothing here redistributes it.
    msi = "EuroScopeSetup.#{version}.msi"
    pkgshare.install msi

    # EUROSCOPE_CLI is a single-quoted heredoc on purpose: the script contains
    # backslashes (the pgrep pattern, Wine registry keys) that an interpolating
    # heredoc would eat. Values come in through placeholders instead.
    cli = EUROSCOPE_CLI.gsub("@@MSI@@", (pkgshare/msi).to_s)
                       .gsub("@@VERSION@@", version.to_s)
    (bin/"euroscope").write cli
    chmod 0755, bin/"euroscope"
  end

  def caveats
    <<~EOS
      EuroScope itself is not installed yet — this formula installs the launcher.
      Finish the install with:

        euroscope setup

      That installs Wine (WineHQ-stable, into /Applications), creates a Wine
      prefix at ~/.wine-euroscope, adds the VC++ runtime EuroScope needs, and
      runs the installer. On Apple Silicon it requires Rosetta 2:

        softwareupdate --install-rosetta --agree-to-license

      Then launch it with `euroscope run`, or build a double-clickable app:

        euroscope app

      Point it at your sector packages by exporting EUROSCOPE_SECTOR_DIR before
      running setup; they get mapped to drive S: inside the prefix.

        euroscope status      shows what is installed
        euroscope uninstall   removes the prefix, the app and the caches
    EOS
  end

  test do
    assert_match "EuroScope", shell_output("#{bin}/euroscope --help")
    assert_path_exists pkgshare/"EuroScopeSetup.#{version}.msi"
  end

  EUROSCOPE_CLI = <<~'BASH'.freeze
    #!/usr/bin/env bash
    set -euo pipefail

    # EuroScope on macOS, under Wine. Installed by the JianyueLab Homebrew tap.
    #
    # EuroScope is a 32-bit Win32/MFC program and cannot be built for macOS, so
    # this drives Wine instead, with no change to the EuroScope binary at all.

    ES_VERSION="@@VERSION@@"
    MSI="${EUROSCOPE_MSI:-@@MSI@@}"

    PREFIX="${EUROSCOPE_PREFIX:-$HOME/.wine-euroscope}"
    ES_DIR="$PREFIX/drive_c/Program Files (x86)/EuroScope"
    ES_EXE="$ES_DIR/EuroScope.exe"
    FSD_EXE="$ES_DIR/EuroScopeFsdServer.exe"
    APP="${EUROSCOPE_APP_DIR:-$HOME/Applications/EuroScope.app}"
    CACHE="${EUROSCOPE_CACHE_DIR:-$HOME/.cache/euroscope}"
    DXVK_CACHE="$CACHE/dxvk"
    SECTOR_DIR="${EUROSCOPE_SECTOR_DIR:-}"
    SECTOR_DRIVE="${EUROSCOPE_SECTOR_DRIVE:-s}"

    # WineHQ-stable for macOS. This is the exact build, URL and checksum that
    # Homebrew's own wine-stable cask used -- but Homebrew deprecated every
    # WineHQ cask over notarization and disables them on 2026-09-01, so fetching
    # it directly is what keeps working. It also skips the cask's
    # gstreamer-runtime dependency, a .pkg that needs sudo to install something
    # EuroScope never uses (its sounds go through winmm).
    WINE_VERSION="11.0_1"
    WINE_TARBALL="wine-stable-${WINE_VERSION}-osx64.tar.xz"
    WINE_URL="https://github.com/Gcenx/macOS_Wine_builds/releases/download/${WINE_VERSION}/${WINE_TARBALL}"
    WINE_SHA256="b50dc50ec7f41d58b115a6b685d4d1315ba3c797bd3aa0f49213f2703cb82388"
    WINE_APP="/Applications/Wine Stable.app"

    # Gcenx's DXVK-macOS, which routes Direct3D to Metal through MoltenVK. The
    # exact build matters: upstream DXVK >= 2.0 refuses to start (MoltenVK has no
    # geometry shaders), upstream 1.10.3 rejects feature levels 11_0/10_0, and
    # mixing Gcenx's d3d11 with upstream's dxgi NULL-derefs creating the device.
    # Only this matched for_crossover pair works.
    DXVK_URL="https://github.com/Gcenx/DXVK-macOS/releases/download/v1.10.3/dxvk-macOS-async-1.10.3_for_crossover.tar.gz"
    DXVK_SHA256="654fbc32da2540fa704e57707ba7593362224a9ce4bb70d71fc6867cdcd8f105"
    DXVK_TARBALL="dxvk-macOS-async-1.10.3_for_crossover.tar.gz"
    DXVK_SRCDIR="dxvk-macOS-async-1.10.3"
    DXVK_MARKER='v1.10.3-async (macOS)'

    VC_BASE="https://aka.ms/vs/17/release"

    die() { echo "Error: $*" >&2; exit 1; }
    info() { echo "==> $*"; }

    find_wine_bin() {
        local name="${1:-wine}" c d
        c="$(command -v "$name" 2>/dev/null || true)"
        [ -n "$c" ] && { printf '%s' "$c"; return 0; }
        for d in "$WINE_APP" "$HOME/Applications/Wine Stable.app" \
                 "/Applications/Wine Devel.app" "/Applications/Wine Staging.app"; do
            [ -x "$d/Contents/Resources/wine/bin/$name" ] && {
                printf '%s' "$d/Contents/Resources/wine/bin/$name"; return 0; }
        done
        return 1
    }

    # Wine's macOS build is x86_64. On Apple Silicon every call has to go through
    # Rosetta, and forgetting the wrapper fails with "Bad CPU type" only once
    # something execs a child process.
    wine_run() {
        local w
        w="$(find_wine_bin wine)" || die "Wine not found. Run: euroscope setup"
        WINEPREFIX="$PREFIX" /usr/bin/arch -x86_64 "$w" "$@"
    }

    wine_kill() {
        local ws
        ws="$(find_wine_bin wineserver 2>/dev/null)" || return 0
        WINEPREFIX="$PREFIX" /usr/bin/arch -x86_64 "$ws" -k >/dev/null 2>&1 || true
    }

    have_rosetta() { /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1; }

    # grep the DLL directly rather than `strings ... | grep -q`: under pipefail
    # that pipeline reports failure whenever grep exits before strings finishes
    # writing, so DXVK reads as missing on a prefix that has it. It depends on
    # timing, so it looks fine by hand and then reinstalls DXVK on every launch.
    dxvk_installed() {
        grep -qa "$DXVK_MARKER" "$PREFIX/drive_c/windows/syswow64/dxgi.dll" 2>/dev/null
    }

    euroscope_running() { pgrep -f 'EuroScope\\EuroScope\.exe' >/dev/null 2>&1; }

    fetch() { # url dest sha256
        local url="$1" dest="$2" want="$3" got
        if [ ! -f "$dest" ]; then
            info "Downloading $(basename "$dest")"
            curl -fL --retry 3 -o "$dest.part" "$url"
            mv "$dest.part" "$dest"
        fi
        if [ -n "$want" ]; then
            got="$(shasum -a 256 "$dest" | awk '{print $1}')"
            [ "$got" = "$want" ] ||
                die "checksum mismatch for $(basename "$dest"): expected $want, got $got. Delete $dest and retry."
        fi
    }

    require_rosetta() {
        [ "$(uname -m)" = "arm64" ] || return 0
        have_rosetta || die "Rosetta 2 is required to run Wine's x86_64 build. Install it with:
        softwareupdate --install-rosetta --agree-to-license"
    }

    install_wine() {
        if find_wine_bin wine >/dev/null 2>&1; then
            info "Wine already present: $(find_wine_bin wine)"
            return 0
        fi
        mkdir -p "$CACHE"
        fetch "$WINE_URL" "$CACHE/$WINE_TARBALL" "$WINE_SHA256"
        info "Installing Wine to $WINE_APP"
        # curl sets no com.apple.quarantine, so Gatekeeper does not block the
        # unnotarized bundle -- the same effect the cask needed --no-quarantine for.
        tar -xJf "$CACHE/$WINE_TARBALL" -C /Applications

        local d
        for d in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
            [ -d "$d" ] && [ -w "$d" ] || continue
            info "Linking wine binaries into $d"
            local n src
            for n in wine wineserver wineboot winecfg winepath regedit msiexec; do
                src="$WINE_APP/Contents/Resources/wine/bin/$n"
                [ -x "$src" ] || continue
                # Never clobber a real file someone else installed.
                if [ -e "$d/$n" ] && [ ! -L "$d/$n" ]; then continue; fi
                ln -sf "$src" "$d/$n"
            done
            break
        done
    }

    install_dxvk() {
        dxvk_installed && { info "DXVK already installed"; return 0; }
        [ -d "$PREFIX/drive_c/windows/syswow64" ] || die "prefix not ready"
        mkdir -p "$CACHE"
        fetch "$DXVK_URL" "$CACHE/$DXVK_TARBALL" "$DXVK_SHA256"

        local tmp
        tmp="$(mktemp -d)"
        tar -xzf "$CACHE/$DXVK_TARBALL" -C "$tmp"

        local backup
        backup="$CACHE/wined3d-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup"
        local dll
        for dll in d3d11 dxgi d3d10 d3d10_1 d3d10core; do
            [ -f "$PREFIX/drive_c/windows/syswow64/$dll.dll" ] &&
                cp "$PREFIX/drive_c/windows/syswow64/$dll.dll" "$backup/$dll.dll"
        done
        info "Wine's original d3d/dxgi DLLs backed up to $backup"

        info "Installing DXVK-macOS"
        local f
        for f in "$tmp/$DXVK_SRCDIR"/x32/*.dll; do
            cp -f "$f" "$PREFIX/drive_c/windows/syswow64/$(basename "$f")"
        done
        for f in "$tmp/$DXVK_SRCDIR"/x64/*.dll; do
            cp -f "$f" "$PREFIX/drive_c/windows/system32/$(basename "$f")"
        done
        rm -rf "$tmp"

        for dll in d3d11 dxgi d3d10core d3d10 d3d10_1 d3dcompiler_47; do
            wine_run reg add "HKCU\\Software\\Wine\\DllOverrides" \
                /v "$dll" /d "native,builtin" /f >/dev/null 2>&1 || true
        done
    }

    link_sector() {
        [ -n "$SECTOR_DIR" ] || return 0
        local link="$PREFIX/dosdevices/${SECTOR_DRIVE}:"
        # An uninitialised checkout is an empty directory that still passes -d;
        # mapping the drive at it yields a drive with nothing on it.
        if [ ! -d "$SECTOR_DIR" ] ||
           [ -z "$(find "$SECTOR_DIR" -name '*.prf' -maxdepth 3 -print -quit 2>/dev/null)" ]; then
            echo "    No sector packages at $SECTOR_DIR -- skipping drive mapping."
            return 0
        fi
        if [ -L "$link" ]; then rm -f "$link"
        elif [ -e "$link" ]; then
            echo "    $link exists and is not a symlink -- leaving it alone."
            return 0
        fi
        ln -s "$SECTOR_DIR" "$link"
        info "Sector packages mapped to $(printf '%s' "$SECTOR_DRIVE" | tr '[:lower:]' '[:upper:]'): -> $SECTOR_DIR"
    }

    cmd_setup() {
        local want_dxvk=1
        case "${1:-}" in
            --no-dxvk) want_dxvk=0 ;;
            "") ;;
            *) die "unknown option: $1" ;;
        esac

        [ -f "$MSI" ] || die "installer not found at $MSI"
        require_rosetta
        install_wine

        # EuroScope needs neither .NET nor an embedded browser, and these two
        # prompts block an unattended install.
        export WINEDLLOVERRIDES="mscoree,mshtml="

        if [ ! -d "$PREFIX/drive_c" ]; then
            info "Creating Wine prefix at $PREFIX (win64)"
            mkdir -p "$PREFIX"
            WINEARCH=win64 wine_run wineboot -i
        fi

        # EuroScope is an MFC program and needs mfc140.dll, which Wine does not
        # ship. winetricks' vcrun verbs install it incompletely, so this uses
        # Microsoft's own redistributable -- the same one euroscope.hu links.
        # On a win64 prefix the 32-bit DLLs land in syswow64, and EuroScope is
        # 32-bit, so that is the copy to test for.
        if [ ! -f "$PREFIX/drive_c/windows/syswow64/mfc140.dll" ]; then
            info "Installing the VC++ 2015-2022 runtime"
            mkdir -p "$CACHE"
            local a
            for a in x86 x64; do
                fetch "$VC_BASE/vc_redist.$a.exe" "$CACHE/vc_redist.$a.exe" ""
                wine_run "$CACHE/vc_redist.$a.exe" /install /quiet /norestart || true
            done
            [ -f "$PREFIX/drive_c/windows/syswow64/mfc140.dll" ] ||
                die "mfc140.dll still missing; EuroScope will not start without it"
        fi

        if [ ! -f "$ES_EXE" ]; then
            info "Installing EuroScope $ES_VERSION"
            wine_run msiexec /i "$MSI" /qn
        fi
        [ -f "$ES_EXE" ] || die "EuroScope.exe is not where the installer should have put it"

        [ "$want_dxvk" = 1 ] && install_dxvk
        link_sector

        echo
        info "Done. EuroScope is installed at:"
        echo "    $ES_EXE"
        echo
        echo "Run it with:  euroscope run      (or 'euroscope app' for a double-clickable app)"
    }

    cmd_run() {
        [ -f "$ES_EXE" ] || die "EuroScope is not installed. Run: euroscope setup"
        mkdir -p "$DXVK_CACHE"
        # Without a writable cache path DXVK recompiles every pipeline on each
        # launch, since it writes .dxvk-cache next to the working directory.
        export DXVK_STATE_CACHE_PATH="$DXVK_CACHE"
        export WINEDEBUG="${WINEDEBUG:--all}"
        export MVK_CONFIG_FAST_MATH_ENABLED=1
        info "Starting EuroScope (prefix: $PREFIX)"
        cd "$ES_DIR"
        wine_run "$ES_EXE" "$@"
    }

    cmd_fsd_server() {
        [ -f "$FSD_EXE" ] || die "EuroScope is not installed. Run: euroscope setup"
        export WINEDEBUG="${WINEDEBUG:--all}"
        info "Starting the bundled EuroScope FSD server"
        wine_run "$FSD_EXE" "$@"
    }

    cmd_app() {
        [ -f "$ES_EXE" ] || die "EuroScope is not installed. Run: euroscope setup"
        case "$APP" in *.app) ;; *) die "refusing to build at $APP" ;; esac
        [ -e "$APP" ] && [ ! -d "$APP/Contents" ] &&
            die "$APP exists and is not an app bundle"

        rm -rf "$APP"
        mkdir -p "$APP/Contents/MacOS"

        cat > "$APP/Contents/Info.plist" <<'PLIST'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    	<key>CFBundleName</key>	<string>EuroScope</string>
    	<key>CFBundleDisplayName</key>	<string>EuroScope</string>
    	<key>CFBundleIdentifier</key>	<string>hu.euroscope.EuroScope</string>
    	<key>CFBundleExecutable</key>	<string>EuroScope</string>
    	<key>CFBundlePackageType</key>	<string>APPL</string>
    	<key>CFBundleShortVersionString</key>	<string>3.2.13</string>
    	<key>LSMinimumSystemVersion</key>	<string>13.0</string>
    	<key>NSHighResolutionCapable</key>	<true/>
    </dict>
    </plist>
    PLIST

        # The launcher re-derives everything itself so the app keeps working even
        # if this CLI is uninstalled.
        cat > "$APP/Contents/MacOS/EuroScope" <<'LAUNCHER'
    #!/usr/bin/env bash
    set -euo pipefail
    PREFIX="${EUROSCOPE_PREFIX:-$HOME/.wine-euroscope}"
    ES_DIR="$PREFIX/drive_c/Program Files (x86)/EuroScope"
    EXE="$ES_DIR/EuroScope.exe"
    LOG_DIR="$HOME/Library/Logs/EuroScope"
    mkdir -p "$LOG_DIR"
    LOG="$LOG_DIR/EuroScope.log"

    die() {
        osascript -e "display dialog \"$1\" with title \"EuroScope\" with icon caution buttons {\"OK\"}" >/dev/null 2>&1 || true
        echo "$1" >> "$LOG"; exit 1
    }
    find_wine_bin() {
        local n="${1:-wine}" c d
        c="$(command -v "$n" 2>/dev/null || true)"
        [ -n "$c" ] && { printf '%s' "$c"; return 0; }
        for d in /opt/homebrew/bin /usr/local/bin \
                 "/Applications/Wine Stable.app/Contents/Resources/wine/bin" \
                 "$HOME/Applications/Wine Stable.app/Contents/Resources/wine/bin"; do
            [ -x "$d/$n" ] && { printf '%s' "$d/$n"; return 0; }
        done
        return 1
    }
    WINE_BIN="$(find_wine_bin wine || true)"
    [ -n "$WINE_BIN" ] || die "Wine is not installed. Run 'euroscope setup' in a terminal."
    [ -f "$EXE" ] || die "EuroScope is not installed. Run 'euroscope setup' in a terminal."

    # A real EuroScope process runs the Windows path "...\EuroScope\EuroScope.exe",
    # which no shell or helper ever contains.
    if pgrep -f 'EuroScope\\EuroScope\.exe' >/dev/null 2>&1; then
        osascript -e 'display dialog "EuroScope is already running." with title "EuroScope" with icon note buttons {"OK"}' >/dev/null 2>&1 || true
        exit 0
    fi

    WS="$(find_wine_bin wineserver || true)"
    [ -n "$WS" ] && WINEPREFIX="$PREFIX" /usr/bin/arch -x86_64 "$WS" -k >/dev/null 2>&1 || true
    sleep 1

    echo "== $(date '+%Y-%m-%d %H:%M:%S') EuroScope starting (wine: $WINE_BIN)" >> "$LOG"
    CACHE_DIR="$HOME/.cache/euroscope/dxvk"
    mkdir -p "$CACHE_DIR"
    export WINEPREFIX="$PREFIX"
    # The app's working directory is /, where DXVK cannot write its .dxvk-cache.
    export DXVK_STATE_CACHE_PATH="$CACHE_DIR"
    export WINEDEBUG="${WINEDEBUG:--all}"
    export MVK_CONFIG_FAST_MATH_ENABLED=1
    cd "$ES_DIR"
    /usr/bin/arch -x86_64 "$WINE_BIN" "$EXE" >> "$LOG" 2>&1 || true
    echo "== $(date '+%Y-%m-%d %H:%M:%S') EuroScope exited" >> "$LOG"
    # EuroScope is known to hang on exit under Wine; tear the server down so the
    # next launch starts clean.
    [ -n "$WS" ] && WINEPREFIX="$PREFIX" /usr/bin/arch -x86_64 "$WS" -k >/dev/null 2>&1 || true
    exit 0
    LAUNCHER
        chmod +x "$APP/Contents/MacOS/EuroScope"
        touch "$APP"
        info "Built $APP"
        echo "Double-click it, or drag it to the Dock."
    }

    cmd_status() {
        echo "EuroScope : ${ES_VERSION}"
        echo "Wine      : $(find_wine_bin wine 2>/dev/null || echo missing)"
        echo "Rosetta   : $(if [ "$(uname -m)" != arm64 ]; then echo 'n/a (Intel)'; \
                            elif have_rosetta; then echo OK; else echo missing; fi)"
        echo "Prefix    : $([ -f "$ES_EXE" ] && echo "OK ($PREFIX)" || echo missing)"
        echo "DXVK      : $(if dxvk_installed; then echo 'Gcenx DXVK-macOS'; \
                            elif [ -f "$PREFIX/drive_c/windows/syswow64/dxgi.dll" ]; then echo 'Wine builtin'; \
                            else echo missing; fi)"
        echo "Sector    : $(readlink "$PREFIX/dosdevices/${SECTOR_DRIVE}:" 2>/dev/null || echo 'not mapped')"
        echo "App       : $([ -d "$APP" ] && echo "$APP" || echo missing)"
        echo "Running   : $(euroscope_running && echo yes || echo no)"
    }

    cmd_uninstall() {
        info "Stopping EuroScope"
        wine_kill
        sleep 1
        info "Removing $APP"
        rm -rf "$APP"
        info "Removing logs and caches"
        rm -rf "$HOME/Library/Logs/EuroScope" "$CACHE"
        info "Removing prefix $PREFIX"
        rm -rf "$PREFIX"
        echo
        echo "Wine itself was left at $WINE_APP; delete it by hand if you want it gone."
        echo "Remove this launcher with: brew uninstall euroscope"
    }

    usage() {
        cat <<'EOF'
    EuroScope on macOS, under Wine.

    Usage: euroscope <command>

      setup [--no-dxvk]  Install Wine, create the prefix, install EuroScope
      run                Launch EuroScope in this terminal
      app                Build ~/Applications/EuroScope.app
      status             Show what is installed and whether it is running
      fsd-server         Run the bundled offline FSD server
      uninstall          Remove the prefix, the app, logs and caches

    Environment:
      EUROSCOPE_PREFIX       Wine prefix           (default ~/.wine-euroscope)
      EUROSCOPE_SECTOR_DIR   Sector packages to map to a drive letter
      EUROSCOPE_SECTOR_DRIVE Drive letter for them (default s)
      EUROSCOPE_APP_DIR      Where to build the app bundle
      EUROSCOPE_MSI          Use a different EuroScope installer
    EOF
    }

    case "${1:-}" in
        setup)              shift; cmd_setup "${1:-}" ;;
        run)                shift; cmd_run "$@" ;;
        app)                cmd_app ;;
        status)             cmd_status ;;
        fsd-server)         shift; cmd_fsd_server "$@" ;;
        uninstall)          cmd_uninstall ;;
        -h|--help|help|"")  usage ;;
        *)                  usage; exit 1 ;;
    esac
  BASH
end
