# Source Maps

Upload JS source maps, ProGuard mapping files (Android), and dSYM files (iOS) so crash stack traces show original source locations.

## Verify CLI

```bash
yarn pulse-cli --version
yarn pulse-cli upload -h
```

## Android

**JS source map only:**
```bash
yarn pulse-cli upload react-native-android \
  --api-url=https://your-pulse-backend.com \
  --api-key=YOUR_API_KEY \
  --app-version=1.0.0 \
  --version-code=7 \
  --js-sourcemap=./android/app/build/intermediates/sourcemaps/react/release/index.android.bundle.packager.map
```

**JS source map + ProGuard mapping:**
```bash
yarn pulse-cli upload react-native-android \
  --api-url=https://your-pulse-backend.com \
  --api-key=YOUR_API_KEY \
  --app-version=1.0.0 \
  --version-code=7 \
  --js-sourcemap=./android/app/build/intermediates/sourcemaps/react/release/index.android.bundle.packager.map \
  --mapping=./android/app/build/outputs/mapping/release/mapping.txt
```

**Android options:**

| Option | Required | Description |
|---|---|---|
| `--api-url` / `-u` | Yes | Your Pulse backend URL |
| `--api-key` / `-k` | Yes | API key |
| `--app-version` / `-v` | Yes | App version string (e.g. `1.0.0`) |
| `--version-code` / `-c` | Yes | Version code integer |
| `--js-sourcemap` / `-j` | Yes | Path to JS source map |
| `--mapping` / `-m` | No | Path to ProGuard mapping file |
| `--bundle-id` / `-b` | No | CodePush bundle label for OTA builds |

## iOS

**JS source map only:**
```bash
yarn pulse-cli upload react-native-ios \
  --api-url=https://your-pulse-backend.com \
  --api-key=YOUR_API_KEY \
  --bundle-version=1.0.0 \
  --version-code=123 \
  --js-sourcemap=./ios/build/Build/Products/Release-iphoneos/main.jsbundle.map
```

**JS source map + dSYM:**
```bash
yarn pulse-cli upload react-native-ios \
  --api-url=https://your-pulse-backend.com \
  --api-key=YOUR_API_KEY \
  --bundle-version=1.0.0 \
  --version-code=123 \
  --js-sourcemap=./ios/build/Build/Products/Release-iphoneos/main.jsbundle.map \
  --dsym=./ios/build/Build/Products/Release-iphoneos/MyApp.app.dSYM
```

**iOS options:**

| Option | Required | Description |
|---|---|---|
| `--api-url` / `-u` | Yes | Your Pulse backend URL |
| `--api-key` / `-k` | Yes | API key |
| `--bundle-version` / `-v` | Yes | `CFBundleShortVersionString` from Info.plist |
| `--version-code` / `-c` | Yes | Version code integer |
| `--js-sourcemap` / `-j` | Yes | Path to JS source map |
| `--dsym` / `-p` | No | Path to `.dSYM` bundle for native symbolication |
| `--bundle-id` / `-b` | No | CodePush bundle label for OTA builds |

## CodePush / OTA Tracking

Set `codeBundleId` in JS to link source maps to OTA bundles:

```typescript
import codePush from 'react-native-code-push';
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

const update = await codePush.getUpdateMetadata();
Pulse.setGlobalAttribute('codeBundleId', update?.label ?? 'embedded');
```

Pass the same label as `--bundle-id` when uploading source maps.
