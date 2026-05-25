# Source Maps (Expo)

Upload JS source maps so crash stack traces resolve to original TypeScript/JavaScript source lines.

## Verify CLI

```bash
yarn pulse-cli --version
```

## Android

```bash
yarn pulse-cli upload react-native-android \
  --api-url=https://your-pulse-backend.com \
  --api-key=YOUR_API_KEY \
  --app-version=1.0.0 \
  --version-code=7 \
  --js-sourcemap=./android/app/build/intermediates/sourcemaps/react/release/index.android.bundle.packager.map
```

With ProGuard mapping:
```bash
yarn pulse-cli upload react-native-android \
  ... \
  --mapping=./android/app/build/outputs/mapping/release/mapping.txt
```

## iOS

```bash
yarn pulse-cli upload react-native-ios \
  --api-url=https://your-pulse-backend.com \
  --api-key=YOUR_API_KEY \
  --bundle-version=1.0.0 \
  --version-code=123 \
  --js-sourcemap=./ios/build/Build/Products/Release-iphoneos/main.jsbundle.map
```

With dSYM for native symbolication:
```bash
yarn pulse-cli upload react-native-ios \
  ... \
  --dsym=./ios/build/Build/Products/Release-iphoneos/MyApp.app.dSYM
```

## CodePush / OTA

Set `codeBundleId` so Pulse can match crash reports to the correct source map:

```typescript
import codePush from 'react-native-code-push';
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

const update = await codePush.getUpdateMetadata();
Pulse.setGlobalAttribute('codeBundleId', update?.label ?? 'embedded');
```

Pass the same label as `--bundle-id` when uploading.
