cask "notchnotch" do
  version "27.1.3"
  sha256 "7ac35699fc7dd49aa3c67af4d0734019a01bf83fa23e77ad0b824dbccbdfdb82"

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
