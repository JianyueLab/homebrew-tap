cask "euroscope" do
  version "3.2.13"
  sha256 "ba1fe4050ec8f8172567e9022b2c5da8198efa1d02986dfcd2f326bf2cd695c0"

  url "https://euroscope.hu/install/EuroScopeSetup.#{version}.msi",
      verified: "euroscope.hu/install/"
  name "EuroScope"
  desc "ATC radar client for flight-sim networks, running under Wine"
  homepage "https://www.euroscope.hu/"

  # A bare symbol means "this version or newer"; the ">= :ventura" string form
  # is deprecated and warns.
  depends_on macos: :ventura

  # There is deliberately no second cask for an older release, and adding one is
  # not just a matter of writing the file. euroscope.hu publishes exactly one
  # version at /install/ (3.2.13 today, plus a stray 3.2.3.2); everything else
  # 404s, and a cask cannot exist without a public url. Mirroring the installer
  # ourselves to create that url is what the EULA forbids:
  #
  #   "Limitations on Redistribution of Software Product. You may not
  #    redistribute the Software Product in whole or part in any way without the
  #    express prior written approval of the Developer."
  #
  # So an older version needs either that written approval from the developer,
  # or no cask at all -- point EUROSCOPE_MSI at a copy you obtained yourself and
  # `euroscope setup` will install it. Should a version reappear upstream, a
  # cask for it is this file with a new version/sha256 and a conflicts_with
  # pointing at the other, since they share one prefix and one command.

  binary "euroscope"

  # EuroScope is a 32-bit Win32/MFC program with no macOS build, so what gets
  # installed is a launcher that drives it under Wine. The implementation is
  # shared by every euroscope cask in this tap -- edit libexec/euroscope.sh,
  # never this file.
  #
  # Everything below goes through `cask.` on purpose. A bare `tap` inside this
  # block does NOT reach the cask's tap: it hits Ruby's own Object#tap, which
  # requires a block, and the install dies with the thoroughly unhelpful
  # "no block given (yield)".
  preflight do
    cli = File.read("#{cask.tap.path}/libexec/euroscope.sh")
              .gsub("@@VERSION@@", cask.version.to_s)
              .gsub("@@TOKEN@@", cask.token.to_s)
              .gsub("@@MSI@@", "#{cask.staged_path}/EuroScopeSetup.#{cask.version}.msi")
    File.write("#{cask.staged_path}/euroscope", cli)
    FileUtils.chmod 0755, "#{cask.staged_path}/euroscope"
  end

  # The Wine prefix, the app bundle, the logs and the caches are created by
  # `euroscope setup` rather than by brew, so they are not cask artifacts and
  # only a zap can take them.
  zap trash: [
    "~/.cache/euroscope",
    "~/.wine-euroscope",
    "~/Applications/EuroScope.app",
    "~/Library/Logs/EuroScope",
  ]

  # `caveats` takes a block in the cask DSL; passing the string directly fails
  # at install time with "no block given (yield)".
  caveats do
    <<~EOS
      EuroScope itself is not installed yet -- this cask installs the launcher.
      Finish the install with:

        euroscope setup

      That installs Wine (WineHQ-stable, into /Applications), creates a Wine
      prefix at ~/.wine-euroscope, adds the VC++ runtime EuroScope needs, and
      runs the installer. On Apple Silicon it requires Rosetta 2:

        softwareupdate --install-rosetta --agree-to-license

      Then launch it with `euroscope run`, or build a double-clickable app with
      `euroscope app`. Point it at your sector packages by exporting
      EUROSCOPE_SECTOR_DIR before running setup; they get mapped to drive S:.

      `euroscope` on its own lists every command. Note that `brew uninstall`
      only removes this launcher -- use `euroscope uninstall`, or `brew zap`, to
      also remove the Wine prefix it built.
    EOS
  end
end
