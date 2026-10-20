cask "notchnotch" do
  version "27.1.4"
  sha256 "d46db032e69b1b705227c167032af46ebbee02b37c02f10f382165c6b6ecbb4a"

  url "https://github.com/JianyueLab-Org/notch/releases/download/v#{version}/NotchNotch-#{version}.zip"
  name "NotchNotch"
  desc "MacBook Pro notch companion panel with media controls, shelf, and clipboard"
  homepage "https://github.com/JianyueLab-Org/notch"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "NotchNotch.app"

  zap trash: [
    "~/Library/Application Support/co.jianyuelab.NotchNotch",
    "~/Library/Caches/co.jianyuelab.NotchNotch",
    "~/Library/Preferences/co.jianyuelab.NotchNotch.plist",
  ]
end
