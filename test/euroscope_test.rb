require "minitest/autorun"
require "open3"
require "tmpdir"
require "fileutils"
require "digest"

class EuroScopeTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRATCH_ROOT = File.join(ROOT, ".temp")

  def setup
    base = File.expand_path(ENV.fetch("TMPDIR"))
    raise "TMPDIR must be inside project .temp" unless base.start_with?("#{SCRATCH_ROOT}/")
    FileUtils.mkdir_p(base)
    @dir = Dir.mktmpdir("euroscope-", base)
    @home = "#{@dir}/home"
    FileUtils.mkdir_p(@home)
    cask = File.read("#{ROOT}/Casks/euroscope.rb")
    @version = cask.match(/^  version "([^"]+)"/)[1]
    body = cask.match(/write_file "euroscope", <<~'BASH'.*?\n(.*?)^    BASH$/m).captures.first
    body = body.lines.map { |line| line.sub(/^      /, "") }.join
    body = body.gsub("{{version}}", cask.match(/^  version "([^"]+)"/)[1])
               .gsub("{{token}}", "euroscope").gsub("{{staged_path}}", @dir)
               .gsub("{{appdir}}", "#{@home}/Applications")
               .gsub('"/Applications/', "\"#{@dir}/Applications/")
    @functions = body.split(/^case "\$\{1:-\}" in\n/).first
    @script = "#{@dir}/euroscope"
    File.write(@script, body)
    FileUtils.chmod(0700, @script)
    tools = "#{@dir}/tools"
    FileUtils.mkdir_p(tools)
    %w[bash basename mkdir cat dirname chmod touch rm shasum perl awk find ln tr readlink uname].each do |name|
      executable = ENV.fetch("PATH").split(File::PATH_SEPARATOR)
                      .map { |directory| File.join(directory, name) }
                      .find { |candidate| File.file?(candidate) && File.executable?(candidate) }
      raise "#{name} must be available in the parent PATH" unless executable
      File.symlink(File.realpath(executable), "#{tools}/#{name}")
    end
    @env = {"HOME" => @home, "PATH" => tools, "EUROSCOPE_PREFIX" => "#{@dir}/prefix",
            "EUROSCOPE_CACHE_DIR" => "#{@dir}/cache", "EUROSCOPE_APP_DIR" => "#{@dir}/EuroScope.app",
            "EUROSCOPE_MSI" => nil, "EUROSCOPE_SECTOR_DIR" => nil}
    @env["EUROSCOPE_SECTOR_DRIVE"] = "s"
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir
  end

  def shell(code, extra = {})
    # Destructive calls are confined even when exercising the vulnerable launcher.
    guard = <<~BASH
      rm() {
        local arg
        for arg in "$@"; do
          case "$arg" in -*) ;; "#{@dir}/"*) ;; *) echo "unsafe rm: $arg" >&2; exit 97 ;; esac
        done
        command rm "$@"
      }
      curl() { echo 'network forbidden' >&2; exit 98; }
      wine_kill() { :; }
      sleep() { :; }
      defaults() {
        if [ -f "$2.bundle-id" ]; then
          cat "$2.bundle-id"
        else
          case "$(cat "$2.plist" 2>/dev/null)" in
            *'<string>hu.euroscope.EuroScope</string>'*) printf '%s' hu.euroscope.EuroScope ;;
            *) return 1 ;;
          esac
        fi
      }
    BASH
    Open3.capture3(@env.merge(extra), "bash", "-c", @functions + "\n" + guard + "\n" + code, chdir: @dir)
  end

  def installed
    path = "#{@dir}/prefix/drive_c/Program Files (x86)/EuroScope"
    FileUtils.mkdir_p(path)
    File.write("#{path}/EuroScope.exe", "fixture")
  end

  def test_rendered_shell_syntax
    _, err, status = Open3.capture3("bash", "-n", @script)
    assert status.success?, err
  end

  def test_uninstall_preserves_containing_directory
    apps = "#{@dir}/Applications"
    FileUtils.mkdir_p("#{apps}/Unrelated.app")
    shell("cmd_uninstall", "EUROSCOPE_APP_DIR" => apps)
    assert File.directory?("#{apps}/Unrelated.app")
  end

  def test_uninstall_preserves_unrelated_bundle
    app = "#{@dir}/Other.app"
    FileUtils.mkdir_p("#{app}/Contents")
    File.write("#{app}/Contents/Info.bundle-id", "org.example.Other")
    shell("cmd_uninstall", "EUROSCOPE_APP_DIR" => app)
    assert File.directory?(app)
  end

  def test_uninstall_removes_owned_bundle
    app = @env["EUROSCOPE_APP_DIR"]
    FileUtils.mkdir_p("#{app}/Contents")
    File.write("#{app}/Contents/Info.bundle-id", "hu.euroscope.EuroScope")
    _, err, status = shell("cmd_uninstall")
    assert status.success?, err
    refute File.exist?(app)
  end

  def test_relative_and_absolute_sector_links
    sector = "#{@dir}/sectors"
    FileUtils.mkdir_p("#{sector}/EDDF")
    File.write("#{sector}/EDDF/EDDF.prf", "fixture")
    FileUtils.mkdir_p("#{@dir}/prefix/dosdevices")
    ["sectors", sector].each do |value|
      out, err, status = shell("link_sector; cmd_status", "EUROSCOPE_SECTOR_DIR" => value)
      assert status.success?, err
      link = "#{@dir}/prefix/dosdevices/s:"
      assert File.exist?(link), "dangling link for #{value}"
      assert_equal sector, File.realpath(link)
      assert_includes out, "Sector    : #{sector}"
    end
  end

  def test_bundle_persists_resolved_paths_and_every_supported_wine_location
    installed
    candidates = [
      "#{@dir}/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine",
      "#{@home}/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine",
      "#{@dir}/Applications/Wine Devel.app/Contents/Resources/wine/bin/wine",
      "#{@dir}/Applications/Wine Staging.app/Contents/Resources/wine/bin/wine",
      "#{@dir}/bin/wine",
    ]
    candidates.each do |wine|
      FileUtils.mkdir_p(File.dirname(wine))
      File.write(wine, "#!/bin/bash\nexit 0\n")
      FileUtils.chmod(0700, wine)
      out, err, status = shell("build_icon() { return 1; }; cmd_app",
        "PATH" => "#{@dir}/bin:#{@env.fetch('PATH')}")
      assert status.success?, out + err
      launcher = File.read("#{@env['EUROSCOPE_APP_DIR']}/Contents/MacOS/EuroScope")
      # Evaluate configuration and Wine resolution only, before macOS execution.
      preamble = launcher.split(/^\[ -n "\$WINE_BIN" \]/).first
      stdout, stderr, result = Open3.capture3(@env.merge("EUROSCOPE_PREFIX" => nil, "EUROSCOPE_CACHE_DIR" => nil),
        "bash", "-c", preamble + "\nprintf '%s\\n%s\\n%s\\n' \"$PREFIX\" \"$CACHE_DIR\" \"$WINE_BIN\"")
      assert result.success?, stderr
      assert_equal [@env['EUROSCOPE_PREFIX'], "#{@dir}/cache/dxvk", wine], stdout.lines.map(&:chomp)
      FileUtils.rm_f(wine)
    end
  end

  def test_bundle_version_uses_installed_receipt_not_installer_filename
    installed
    File.write("#{@dir}/prefix/.euroscope-version", "3.2.9\n")
    out, err, status = shell("build_icon() { return 1; }; cmd_app",
      "EUROSCOPE_MSI" => "#{@dir}/unknown-name.msi")
    assert status.success?, out + err
    plist = File.read("#{@env['EUROSCOPE_APP_DIR']}/Contents/Info.plist")
    assert_match(/CFBundleShortVersionString<\/key>\s*<string>3\.2\.9<\/string>/, plist)
  end

  def test_bundle_does_not_claim_unknown_installed_version
    installed
    out, err, status = shell("build_icon() { return 1; }; cmd_app",
      "EUROSCOPE_MSI" => "#{@dir}/arbitrary-name.msi")
    assert status.success?, out + err
    plist = File.read("#{@env['EUROSCOPE_APP_DIR']}/Contents/Info.plist")
    refute_match(/CFBundleShortVersionString/, plist)
  end

  def test_changed_or_untracked_installer_is_refused_without_prefix_deletion
    installed
    File.write("#{@dir}/selected.msi", "new installer")
    receipt = "#{@dir}/prefix/.euroscope-installer-sha256"
    [nil, Digest::SHA256.hexdigest("old installer")].each do |identity|
      File.write(receipt, identity + "\n") if identity
      out, err, status = shell("require_rosetta() { echo unexpected-mutation >&2; exit 96; }; cmd_setup --no-dxvk",
        "EUROSCOPE_MSI" => "#{@dir}/selected.msi")
      refute status.success?, out + err
      assert_match(/fresh prefix/i, err)
      refute_includes err, "unexpected-mutation"
      assert File.exist?("#{@dir}/prefix/drive_c/Program Files (x86)/EuroScope/EuroScope.exe")
    end
  end

  def test_unchanged_installer_preserves_existing_installation
    installed
    File.write("#{@dir}/selected.msi", "same installer")
    File.write("#{@dir}/prefix/.euroscope-installer-sha256", Digest::SHA256.hexdigest("same installer") + "\n")
    FileUtils.mkdir_p("#{@dir}/prefix/drive_c/windows/syswow64")
    File.write("#{@dir}/prefix/drive_c/windows/syswow64/mfc140.dll", "fixture")
    out, err, status = shell("require_rosetta() { :; }; install_wine() { :; }; wine_wait() { :; }; wine_run() { echo unexpected-installer >&2; exit 96; }; cmd_setup --no-dxvk",
      "EUROSCOPE_MSI" => "#{@dir}/selected.msi")
    assert status.success?, out + err
    assert_equal "fixture", File.read("#{@dir}/prefix/drive_c/Program Files (x86)/EuroScope/EuroScope.exe")
    refute_includes err, "unexpected-installer"
  end

  def test_fresh_packaged_install_records_identity_and_version
    File.write("#{@dir}/EuroScopeSetup.#{@version}.msi", "packaged installer")
    FileUtils.mkdir_p("#{@dir}/prefix/drive_c/windows/syswow64")
    File.write("#{@dir}/prefix/drive_c/windows/syswow64/mfc140.dll", "fixture")
    out, err, status = shell('require_rosetta() { :; }; install_wine() { :; }; wine_wait() { :; }; wine_run() { mkdir -p "$ES_DIR"; printf installed > "$ES_EXE"; }; cmd_setup --no-dxvk')
    assert status.success?, out + err
    assert_equal Digest::SHA256.hexdigest("packaged installer"),
      File.read("#{@dir}/prefix/.euroscope-installer-sha256").strip
    assert_equal @version, File.read("#{@dir}/prefix/.euroscope-version").strip
  end
end
