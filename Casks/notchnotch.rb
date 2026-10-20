cask "notchnotch" do
  version "27.1.5"
  sha256 "91c648544ea3787ffeaa49ab93b3557f1d9978bff71efc05d1270f76ed0c950d"

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
