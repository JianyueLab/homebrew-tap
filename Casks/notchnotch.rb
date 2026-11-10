cask "notchnotch" do
  version "27.2.0"
  sha256 "7ae87f5d42f15ae47ce51219f8a73df2bd331dd1e783df13e3d70fceb4b7ee2d"

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
