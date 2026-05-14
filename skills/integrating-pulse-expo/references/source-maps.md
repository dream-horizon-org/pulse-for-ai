---
name: pulse-source-maps
description: Surface the Pulse CLI commands for uploading JS source maps, ProGuard mappings, and dSYMs. Suggestion-only — does not run uploads, modify CI scripts, or add files to the user's repo on its own.
category: sdk-feature
invoke-when: source maps, readable stack traces, symbolication, dSYM, ProGuard mapping, upload symbols, minified stack trace
allowed-tools: Read, Edit, Bash
---

## Invoke When

- Stack traces in the Pulse dashboard show minified code (`index.bundle:1:12345`).
- User wants to wire symbol uploads into a release / CI process.

---

## Guardrails

- **Surface commands; do not run uploads.** The CLI sends bytes to the Pulse backend with the user's API key — that is a user-driven action.
- **Do not** modify CI / Fastlane / EAS / GitHub Actions configuration on the user's behalf. If they want a CI step, surface the command and let them paste it into the right pipeline.
- **Do not** install `@dreamhorizonorg/pulse-cli` automatically. The CLI ships with the SDK (`yarn pulse-cli`); only suggest a separate install if the user reports `pulse-cli: command not found`.
- **Do not** write `PULSE_API_KEY` to `.env`, CI secret stores, or anywhere else. Surface the env-var name; the user adds the value.
- **Do not** trigger Android / iOS release builds, `eas build`, `expo run:*`, or anything that produces a new bundle. Source maps must come from the user's own release build.

---

## Guard — Pulse Must Be Installed

```bash
grep '"@dreamhorizonorg/pulse-react-native"' package.json 2>/dev/null
```

If not found → tell user to run `/integrating-pulse-expo` first. Stop.

---

## Verify the CLI

The CLI ships with the SDK — no separate install in most cases:

```bash
yarn pulse-cli --version
yarn pulse-cli upload -h
yarn pulse-cli upload react-native-android -h
yarn pulse-cli upload react-native-ios -h
```

If missing, suggest (do not auto-run):

```bash
yarn add --dev @dreamhorizonorg/pulse-cli
# or
npm install --save-dev @dreamhorizonorg/pulse-cli
```

---

## Android — upload JS source map

After a release build, the JS source map sits at:

```
android/app/build/intermediates/sourcemaps/react/release/index.android.bundle.packager.map
```

```bash
yarn pulse-cli upload react-native-android \
  --api-url=https://your-pulse-backend.com \
  --api-key=$PULSE_API_KEY \
  --app-version=1.0.0 \
  --version-code=7 \
  --js-sourcemap=./android/app/build/intermediates/sourcemaps/react/release/index.android.bundle.packager.map
```

With ProGuard mapping (only generated when `minifyEnabled = true` in the release build type):

```bash
yarn pulse-cli upload react-native-android \
  --api-url=https://your-pulse-backend.com \
  --api-key=$PULSE_API_KEY \
  --app-version=1.0.0 \
  --version-code=7 \
  --js-sourcemap=./android/app/build/intermediates/sourcemaps/react/release/index.android.bundle.packager.map \
  --mapping=./android/app/build/outputs/mapping/release/mapping.txt
```

| Option | Required | Description |
|---|---|---|
| `--api-url` / `-u` | Yes | Pulse backend URL |
| `--api-key` / `-k` | Yes | API key (sent as `X-API-KEY`) |
| `--app-version` / `-v` | Yes | App version string (e.g. `1.0.0`) |
| `--version-code` / `-c` | Yes | Version code integer |
| `--js-sourcemap` / `-j` | Yes | JS source map path |
| `--mapping` / `-m` | No | ProGuard mapping path |
| `--bundle-id` / `-b` | No | OTA / CodePush bundle label |
| `--debug` / `-d` | No | Verbose output |

---

## iOS — upload JS source map

After a release build, the JS source map sits at:

```
ios/build/Build/Products/Release-iphoneos/main.jsbundle.map
```

```bash
yarn pulse-cli upload react-native-ios \
  --api-url=https://your-pulse-backend.com \
  --api-key=$PULSE_API_KEY \
  --bundle-version=1.0.0 \
  --version-code=123 \
  --js-sourcemap=./ios/build/Build/Products/Release-iphoneos/main.jsbundle.map
```

With dSYM (for native iOS crash symbolication):

```bash
yarn pulse-cli upload react-native-ios \
  --api-url=https://your-pulse-backend.com \
  --api-key=$PULSE_API_KEY \
  --bundle-version=1.0.0 \
  --version-code=123 \
  --js-sourcemap=./ios/build/Build/Products/Release-iphoneos/main.jsbundle.map \
  --dsym=./ios/build/Build/Products/Release-iphoneos/MyApp.app.dSYM
```

| Option | Required | Description |
|---|---|---|
| `--api-url` / `-u` | Yes | Pulse backend URL |
| `--api-key` / `-k` | Yes | API key (sent as `X-API-KEY`) |
| `--bundle-version` / `-v` | Yes | `CFBundleShortVersionString` from `Info.plist` |
| `--version-code` / `-c` | Yes | Version code integer |
| `--js-sourcemap` / `-j` | Yes | JS source map path |
| `--dsym` / `-p` | No | `.dSYM` bundle path |
| `--bundle-id` / `-b` | No | OTA / CodePush bundle label |
| `--debug` / `-d` | No | Verbose output |

---

## OTA / CodePush correlation

For OTA releases, set `codeBundleId` at runtime so each crash maps to the right uploaded source map:

```typescript
import * as Updates from 'expo-updates';
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.setGlobalAttribute('codeBundleId', Updates.updateId ?? 'embedded');
```

Surface this to the user as the suggested call site (typically right after `PulseService.start()` in the entry point). Insert it only if the user asks. The same value must be passed as `--bundle-id` when uploading the source map for that bundle:

```bash
yarn pulse-cli upload react-native-android \
  ... \
  --bundle-id=$OTA_UPDATE_ID
```

If `--bundle-id` does not match the runtime `codeBundleId`, Pulse cannot correlate the trace.

---

## Wiring into CI

Surface the command for the user to paste into their pipeline (GitHub Actions, Bitrise, Fastlane, EAS post-build hook). Required pieces:

- `PULSE_API_KEY` available as a CI secret
- A release build step that produces the bundle + source map (and optionally ProGuard mapping / dSYM)
- One `yarn pulse-cli upload react-native-{android,ios}` invocation per platform, per release

Do not author the CI YAML on the user's behalf unless they explicitly ask and name the file.

---

## Troubleshooting

- `--debug` for verbose output:
  ```bash
  yarn pulse-cli upload react-native-android --debug
  ```
- ProGuard mapping missing → confirm the release build sets `minifyEnabled = true`.
- dSYM missing → confirm the iOS build is `Release` (Debug builds do not produce a `.dSYM`).
- Stack traces still minified after upload → confirm `--app-version` / `--version-code` (Android) or `--bundle-version` / `--version-code` (iOS) match the values reported in the dashboard for the failing session.
