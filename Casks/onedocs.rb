cask "onedocs" do
  arch arm: "aarch64", intel: "x64"

  version "2.0.0"
  sha256 arm:   "3619b2879bd35f039c32177bdf307097f33e540bdf1067c56bbd5815b160df75",
         intel: "a64f9eb648d5fc66f7c6e420b6d37a2a990feea81f938336bd258117118d52d9"

  url "https://github.com/LYOfficial/OneDocs/releases/download/v#{version}/OneDocs_#{version}_#{arch}.dmg"
  name "OneDocs"
  name "一文亦闻"
  desc "Cross-platform markdown and document reader built with Tauri"
  homepage "https://onedocs.ijune.cn/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on :macos

  app "OneDocs.app"

  zap trash: [
    "~/Library/Application Support/com.ijune.onedocs",
    "~/Library/Caches/com.ijune.onedocs",
    "~/Library/Preferences/com.ijune.onedocs.plist",
    "~/Library/Saved Application State/com.ijune.onedocs.savedState",
    "~/Library/WebKit/com.ijune.onedocs",
  ]
end
