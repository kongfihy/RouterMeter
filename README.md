# OpenRouter Monitor for macOS

OpenRouter Monitor is a native macOS menu bar app for keeping an eye on OpenRouter API spend without opening a browser dashboard.

It is built for developers, AI power users, and small teams using OpenRouter for coding agents, prototypes, production apps, or personal AI workflows. The app shows your current usage at a glance, tracks budget thresholds, and surfaces model-level activity when your API key has access to OpenRouter management analytics.

## Features

- macOS menu bar item with a compact usage readout.
- Native SwiftUI popover dashboard.
- OpenRouter API key stored in Apple Keychain.
- Local-only cache for non-secret settings and usage snapshots.
- Manual and scheduled refresh.
- Key usage summary from OpenRouter.
- Optional account credit balance for management-capable keys.
- Optional model breakdown from OpenRouter activity analytics.
- USD and GBP display, with manual USD-to-GBP conversion.
- Budget alerts for low balance, critical balance, daily spend, and monthly spend.
- Direct link to the OpenRouter dashboard.

## What It Shows

The menu bar can show one of three display modes:

- Remaining balance
- Percent remaining
- Today's spend

The popover dashboard shows:

- Current balance or key limit status
- Today, week, month, and all-time usage
- Top model breakdown for the last 30 completed UTC days when available
- Connection and refresh status
- Quick actions for refresh, dashboard, and settings

## API Access

The app uses the following OpenRouter endpoints:

- `GET /api/v1/key`
  - Used for key-level usage.
  - Works with a normal OpenRouter API key.

- `GET /api/v1/credits`
  - Used for account credit balance.
  - Requires a management-capable key.

- `GET /api/v1/activity`
  - Used for model-level activity grouped by model/endpoint.
  - Requires a management-capable key.
  - Covers the last 30 completed UTC days.

If a management-only endpoint returns `403 Forbidden`, the app still keeps the key-level refresh working and shows a warning for the unavailable account/model data.

## Privacy And Storage

The API key is stored only in Apple Keychain.

Non-secret app data is stored locally at:

```text
~/Library/Application Support/OpenRouterMonitor/state.json
```

That file may contain:

- UI settings
- Budget thresholds
- Cached usage snapshots
- Cached model activity returned by OpenRouter
- Last refresh status and warnings

The app does not send data to any service other than OpenRouter.

## Requirements

- macOS 14 or newer
- Swift toolchain with SwiftPM
- An OpenRouter API key
- A management-capable OpenRouter key for account balance and model activity

## Build

```bash
swift build
```

## Run

```bash
swift run OpenRouterMonitor
```

When launched through SwiftPM, the app runs as a raw executable rather than a packaged `.app` bundle. Most functionality works, but macOS notifications are skipped in this mode because `UNUserNotificationCenter` requires a real app bundle.

## Create a macOS App Bundle

```bash
./scripts/package_app.sh
```

The packaged app is created at:

```text
dist/OpenRouterMonitor.app
```

The local bundle is ad-hoc signed for development use. It is not notarized.

## Create an Installer DMG

```bash
./scripts/package_dmg.sh
```

The DMG is created at:

```text
dist/OpenRouterMonitor.dmg
```

The DMG contains `OpenRouterMonitor.app` and an `Applications` shortcut for drag-to-install. The app inside the DMG is ad-hoc signed for local development, not notarized.

## Install From the DMG

After creating the DMG:

1. Open `dist/OpenRouterMonitor.dmg`.
2. Drag `OpenRouterMonitor.app` into `Applications`.
3. Launch it from Applications.

Because the app is currently ad-hoc signed and not notarized, macOS may show a Gatekeeper warning on first launch outside this development machine.

## Checks

This project includes an executable check target:

```bash
swift run OpenRouterMonitorCoreChecks
```

The checks cover:

- OpenRouter response decoding
- Balance and percent calculations
- USD/GBP display formatting
- Menu bar title formatting
- Alert threshold deduping
- Mocked key-only refresh
- Mocked management refresh
- Activity decoding and model aggregation
- HTTP error mapping
- Malformed response handling
- Transport failure handling

## Project Structure

```text
Sources/
  OpenRouterMonitor/
    SwiftUI macOS app, menu bar UI, dashboard, settings, Keychain, local persistence

  OpenRouterMonitorCore/
    API models, OpenRouter client, refresh service, formatters, alert evaluation

  OpenRouterMonitorCoreChecks/
    Command-line verification target
```

## Current Limitations

- The packaged app and DMG are ad-hoc signed, not notarized.
- Notifications are disabled only when running through `swift run`; use the packaged `.app` for bundle-dependent macOS APIs.
- GBP conversion uses a manual exchange rate.
- Model breakdown depends on OpenRouter management activity access.
- No multi-key or multi-account UI yet.
- No local proxy/import mode for generation-level tracing yet.

## Roadmap

Planned next steps:

- Add Developer ID signing and notarization.
- Add a polished DMG background and layout.
- Add multi-key profiles.
- Add charts for daily and monthly usage trends.
- Add historical model analytics views.
- Add export for cached usage data.
- Add optional local proxy/import support for generation-level cost tracing.

## License

OpenRouter Monitor is licensed under the GNU General Public License v3.0.

See [LICENSE](LICENSE) for the full license text.
