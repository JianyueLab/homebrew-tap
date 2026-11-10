cask "notchnotch" do
  version "27.1.11"
  sha256 "e00de2646f4fcde61786258806e410953d186e0bdaac9d0d721c40f2f1266eae"

  url "https://github.com/JianyueLab-Org/notch/releases/download/v#{version}/NotchNotch-#{version}.zip"
  name "NotchNotch"
  desc "MacBook Pro notch companion panel with media controls, shelf, and clipboard"
  homepage "https://github.com/JianyueLab-Org/notch"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura
  depends_on arch: :arm64

  app "NotchNotch.app"

  zap trash: [
    "~/Library/Application Support/co.jianyuelab.NotchNotch",
    "~/Library/Caches/co.jianyuelab.NotchNotch",
    "~/Library/Preferences/co.jianyuelab.NotchNotch.plist",
  ]
end
