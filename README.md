# BitcoinTicker

A small macOS menu bar app that shows the current Bitcoin price in USD and its 24-hour change.

The menu bar shows something like `$62,345 ▲1.8%`. Click it to see the exact price, the time of the last update, a refresh button, a **Launch at Login** toggle, and **Quit**.

## Requirements

- macOS 13 Ventura or later, on Apple Silicon or Intel (universal binary)
- An internet connection

## Install

Each push to `main` builds the app on GitHub Actions and publishes it in two places:

- **The `dist` branch:** [BitcoinTicker.zip](https://github.com/adambrauntonpers/BitcoinTicker/raw/dist/BitcoinTicker.zip). If the repo is private, sign in to GitHub first.
- **Actions:** open the latest **Build macOS app** run and download the **BitcoinTicker** artifact. It's a zip that contains `BitcoinTicker.zip`, and artifacts expire after 90 days.

Unzip the download and move `BitcoinTicker.app` to `/Applications`.

The app is ad-hoc signed, not notarized, so Gatekeeper blocks it the first time you open it. To allow it, do one of the following:

- Run this in Terminal:
  ```sh
  xattr -dr com.apple.quarantine /Applications/BitcoinTicker.app
  ```
- Or open the app, dismiss the warning, then go to **System Settings → Privacy & Security** and click **Open Anyway**.

You need to do this again for each new build. After replacing the app, switch **Launch at Login** off and on again so macOS registers the new copy.

## How it works

The app fetches the price when it starts and then every 60 seconds:

1. **[CoinGecko](https://www.coingecko.com/en/api)**: the `simple/price` endpoint. It needs no API key, but its limits are shared by everyone on the same public IP, so it often returns HTTP 429 on corporate networks and VPNs.
2. **[Coinbase Exchange](https://docs.cdp.coinbase.com/exchange/)**: the `BTC-USD/stats` endpoint, used when CoinGecko fails. The app calculates the 24-hour change from the `open` and `last` prices.

If both sources fail, the menu keeps showing the last good price with an error explaining why it wasn't updated. The footer of the menu shows which source the current price came from.

The app runs in the App Sandbox with outgoing network access only. It has no Dock icon (`LSUIElement`), and it uses `SMAppService` for Launch at Login.

## Project layout

| File | Purpose |
| --- | --- |
| [BitcoinTickerApp.swift](BitcoinTicker/BitcoinTickerApp.swift) | App entry point, `MenuBarExtra`, and the menu bar label |
| [BitcoinMenuView.swift](BitcoinTicker/BitcoinMenuView.swift) | The panel that opens when you click the menu bar item |
| [BitcoinPriceService.swift](BitcoinTicker/BitcoinPriceService.swift) | Polling, the CoinGecko → Coinbase fallback, and error messages |
| [LaunchAtLoginManager.swift](BitcoinTicker/LaunchAtLoginManager.swift) | Wraps `SMAppService.mainApp` |
| [build.yml](.github/workflows/build.yml) | CI: universal Release build, ad-hoc signing, packaging, publishing to `dist` |

## Building locally

Open `BitcoinTicker.xcodeproj` in Xcode and run the **BitcoinTicker** scheme. To build from the command line the same way CI does:

```sh
xcodebuild \
  -project BitcoinTicker.xcodeproj \
  -scheme BitcoinTicker \
  -configuration Release \
  -derivedDataPath build \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" \
  build
```

The app ends up at `build/Build/Products/Release/BitcoinTicker.app`.

### Keeping macOS 13 support

- The deployment target is `MACOSX_DEPLOYMENT_TARGET = 13.0`. CI builds with the newest Xcode (`macos-latest`), and the deployment target is what keeps the app running on Ventura.
- Don't use APIs that need macOS 14 or later without an `#available` check. In particular:
  - Use `ObservableObject` and `@Published`, not the `@Observable` macro.
  - In the menu bar label, use `foregroundColor` on `Text`, because `foregroundStyle` only returns `Text` from macOS 14.
- The project uses Swift 5 language mode (`SWIFT_VERSION = 5.0`). Moving to Swift 6 turns on strict concurrency checking, which would require changes in `BitcoinPriceService`.
