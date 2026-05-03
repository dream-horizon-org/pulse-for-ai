# Expo Plugin Reference

Full `app.json` configuration for `@dreamhorizonorg/pulse-react-native`.

## Minimal Config

```json
[
  "@dreamhorizonorg/pulse-react-native",
  {
    "apiKey": "YOUR_API_KEY",
    "dataCollectionState": "ALLOWED"
  }
]
```

`apiKey` and `dataCollectionState` at root apply to both platforms. Override per-platform with `android` / `ios` blocks.

## Root Options

| Option | Required | Values | Description |
|---|---|---|---|
| `apiKey` | Yes | string | Project API key from Pulse dashboard |
| `dataCollectionState` | Yes | `"ALLOWED"`, `"PENDING"`, `"DENIED"` | Initial data collection state |
| `android` | No | object | Android-specific overrides |
| `ios` | No | object | iOS-specific overrides |

## Android Options

| Option | Description |
|---|---|
| `apiKey` | Override API key for Android only |
| `dataCollectionState` | Override consent state for Android only |
| `globalAttributes` | Key/value pairs attached to all Android telemetry |
| `logLevel` | Native log verbosity — debugging only, remove in production. `"VERBOSE"`, `"DEBUG"`, `"INFO"`, `"WARN"`, `"ERROR"`, `"NONE"` (default) |
| `coreLibraryDesugaring` | `{ "enabled": true }` — **required if `minSdkVersion < 26`** |
| `okHttpInstrumentation` | `{ "enabled": true }` — native OkHttp spans via ByteBuddy. **Required to capture `Image`, `FastImage`, and any native Android HTTP traffic** that bypasses the JS layer. Optionally add `"byteBuddyGradlePluginVersion"` to override the default (`1.17.8`). |

**Android `instrumentation`** (each takes `{ "enabled": boolean }`):

| Key | Description |
|---|---|
| `crash` | Native crash detection |
| `network` | Network monitoring |
| `activity` | Activity lifecycle — powers AppStart span |
| `fragment` | Fragment lifecycle — **set `false` for RN apps** to avoid double-counting screens |
| `anr` | ANR detection |
| `slowRendering` | Slow/jank frame detection |
| `interaction` | Touch/tap events |

## iOS Options

| Option | Description |
|---|---|
| `apiKey` | Override API key for iOS only |
| `dataCollectionState` | Override consent state for iOS only |
| `globalAttributes` | Key/value pairs attached to all iOS telemetry |
| `logLevel` | Native log verbosity — debugging only, remove in production. `"VERBOSE"`, `"DEBUG"`, `"INFO"`, `"WARN"`, `"ERROR"`, `"NONE"` (default) |

**iOS `configuration`** (booleans):

| Key | Description |
|---|---|
| `includeScreenAttributes` | Attach screen metadata to telemetry |
| `includeNetworkAttributes` | Attach network metadata |
| `includeGlobalAttributes` | Attach global attributes |

**iOS `instrumentation`** (each takes `{ "enabled": boolean }`):

| Key | Description |
|---|---|
| `crash` | Native crash detection |
| `appLifecycle` | Foreground/background transitions |
| `screenLifecycle` | ViewController tracking |
| `appStartup` | Cold start timing |
| `location` | Location updates |

> URLSession is instrumented automatically — no plugin toggle needed. For URL filters and header capture, use the [iOS network guide](https://pulse-ux.com/docs/developer-guide/sdk/ios/instrumentation/network).

## OkHttp / Image / FastImage

`Image`, `FastImage`, and other native Android components use OkHttp — their requests **bypass the JS layer** and are not captured by default.

To capture them, enable `okHttpInstrumentation` in your plugin config:

```json
"android": {
  "okHttpInstrumentation": { "enabled": true }
}
```

This wires the Pulse OkHttp artifacts and the ByteBuddy Gradle plugin at prebuild time. Re-run `npx expo prebuild --clean` after enabling it.

## Full Example

```json
{
  "expo": {
    "plugins": [
      [
        "@dreamhorizonorg/pulse-react-native",
        {
          "apiKey": "YOUR_API_KEY",
          "dataCollectionState": "ALLOWED",
          "android": {
            "coreLibraryDesugaring": { "enabled": true },
            "okHttpInstrumentation": { "enabled": true },
            "instrumentation": {
              "fragment":      { "enabled": false },
              "crash":         { "enabled": true },
              "network":       { "enabled": true },
              "anr":           { "enabled": true },
              "slowRendering": { "enabled": true },
              "interaction":   { "enabled": true }
            }
          },
          "ios": {
            "configuration": {
              "includeScreenAttributes": true,
              "includeNetworkAttributes": true
            },
            "instrumentation": {
              "crash":           { "enabled": true },
              "screenLifecycle": { "enabled": true },
              "appStartup":      { "enabled": true }
            }
          }
        }
      ]
    ]
  }
}
```

## Data Collection Consent States

| State | Behavior |
|---|---|
| `ALLOWED` | Telemetry collected and exported immediately |
| `PENDING` | SDK initialized — data buffered in memory, nothing exported |
| `DENIED` | Terminal — buffer cleared, SDK shuts down |

**Valid transitions:**
- `PENDING` → `ALLOWED`: flushes buffer, starts exporting
- `PENDING` → `DENIED`: clears buffer, shuts down
- `ALLOWED` → `DENIED`: clears buffer, shuts down
- `DENIED` → anything: invalid — requires app restart

Re-run `npx expo prebuild --clean` after any plugin config change.
