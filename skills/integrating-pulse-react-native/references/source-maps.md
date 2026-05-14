---
name: pulse-source-maps
description: Upload JS source maps and native symbol files to make crash stack traces readable in an existing Pulse bare React Native setup.
category: sdk-feature
invoke-when: source maps, readable stack traces, symbolication, dSYM, ProGuard mapping, upload symbols, crash traces unreadable, minified stack trace
allowed-tools: Read, Edit, Bash
---

## Invoke When

- User asks "upload source maps to Pulse" or "make crash traces readable"
- Stack traces in the dashboard show minified code (`index.bundle:1:12345`)
- User is setting up CI/CD and wants automated symbol upload
- Pulse is already set up

---

## Guard — Pulse Must Be Installed

```bash
grep '"@dreamhorizonorg/pulse-react-native"' package.json 2>/dev/null
```

If not found → tell user to run `/integrating-pulse-react-native` first. Do not proceed.

---

## Verify CLI

```bash
yarn pulse-cli --version
```

If not installed: `yarn add --dev @dreamhorizonorg/pulse-cli` or `npm install --save-dev @dreamhorizonorg/pulse-cli`.

---

## Android — Upload JS Source Map

Build a release first, then upload:

```bash
yarn pulse-cli upload react-native-android \
  --api-url=https://your-pulse-backend.com \
  --api-key=$PULSE_API_KEY \
  --app-version=1.0.0 \
  --version-code=7 \
  --js-sourcemap=./android/app/build/intermediates/sourcemaps/react/release/index.android.bundle.packager.map
```

With ProGuard mapping (recommended for release builds):
```bash
yarn pulse-cli upload react-native-android \
  --api-url=https://your-pulse-backend.com \
  --api-key=$PULSE_API_KEY \
  --app-version=1.0.0 \
  --version-code=7 \
  --js-sourcemap=./android/app/build/intermediates/sourcemaps/react/release/index.android.bundle.packager.map \
  --mapping=./android/app/build/outputs/mapping/release/mapping.txt
```

**Options:**

| Option | Required | Description |
|---|---|---|
| `--api-url` / `-u` | Yes | Pulse backend URL |
| `--api-key` / `-k` | Yes | API key |
| `--app-version` / `-v` | Yes | Version string (e.g. `1.0.0`) |
| `--version-code` / `-c` | Yes | Version code integer |
| `--js-sourcemap` / `-j` | Yes | Path to JS source map |
| `--mapping` / `-m` | No | Path to ProGuard mapping file |
| `--bundle-id` / `-b` | No | CodePush bundle label for OTA builds |

---

## iOS — Upload JS Source Map

```bash
yarn pulse-cli upload react-native-ios \
  --api-url=https://your-pulse-backend.com \
  --api-key=$PULSE_API_KEY \
  --bundle-version=1.0.0 \
  --version-code=123 \
  --js-sourcemap=./ios/build/Build/Products/Release-iphoneos/main.jsbundle.map
```

With dSYM for native crash symbolication:
```bash
yarn pulse-cli upload react-native-ios \
  --api-url=https://your-pulse-backend.com \
  --api-key=$PULSE_API_KEY \
  --bundle-version=1.0.0 \
  --version-code=123 \
  --js-sourcemap=./ios/build/Build/Products/Release-iphoneos/main.jsbundle.map \
  --dsym=./ios/build/Build/Products/Release-iphoneos/MyApp.app.dSYM
```

**Options:**

| Option | Required | Description |
|---|---|---|
| `--api-url` / `-u` | Yes | Pulse backend URL |
| `--api-key` / `-k` | Yes | API key |
| `--bundle-version` / `-v` | Yes | `CFBundleShortVersionString` from Info.plist |
| `--version-code` / `-c` | Yes | Version code integer |
| `--js-sourcemap` / `-j` | Yes | Path to JS source map |
| `--dsym` / `-p` | No | Path to `.dSYM` for native crash symbolication |
| `--bundle-id` / `-b` | No | CodePush bundle label for OTA builds |

---

## CodePush / OTA Tracking

Tag the running bundle so crashes map to the correct source map:

```typescript
import codePush from 'react-native-code-push';
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

const update = await codePush.getUpdateMetadata();
Pulse.setGlobalAttribute('codeBundleId', update?.label ?? 'embedded');
```

Pass the same label as `--bundle-id` when uploading.

---

## Automate in CI

Add the upload step after every release build. Set `PULSE_API_KEY` as a CI secret and run upload commands as a post-build step. Upload must run after every new JS bundle — once per release, per platform.
