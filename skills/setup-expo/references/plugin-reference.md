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
| `coreLibraryDesugaring` | `{ "enabled": true }` — **required if minSdkVersion < 26** |

**Android instrumentations** (each takes `{ "enabled": boolean }`):

| Instrumentation | Default | Notes |
|---|---|---|
| `activity` | true | Activity lifecycle — powers AppStart span |
| `fragment` | true | **Set false for RN apps** |
| `crashReporter` | true | Native crash detection |
| `anrReporter` | true | ANR detection |
| `slowRendering` | true | Jank and frozen frame detection |
| `interaction` | true | Touch/tap events |

## iOS Options

| Option | Description |
|---|---|
| `apiKey` | Override API key for iOS only |
| `dataCollectionState` | Override consent state for iOS only |
| `globalAttributes` | Key/value pairs attached to all iOS telemetry |
| `configuration.includeScreenAttributes` | boolean — attach screen metadata |
| `configuration.includeNetworkAttributes` | boolean — attach network metadata |
| `configuration.includeGlobalAttributes` | boolean — attach global attributes |

**iOS instrumentations** (each takes `{ "enabled": boolean }`):

| Instrumentation | Default | Notes |
|---|---|---|
| `urlSession` | true | URLSession network monitoring |
| `crash` | true | Native crash detection |
| `screenLifecycle` | true | ViewController tracking |
| `appStartup` | true | Cold start timing |
| `appLifecycle` | true | Foreground/background transitions |
| `interaction` | true | Touch/tap events |
| `sessions` | true | Session boundary tracking |

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
            "instrumentation": {
              "fragment":   { "enabled": false },
              "activity":   { "enabled": true },
              "crashReporter": { "enabled": true },
              "anrReporter":   { "enabled": true },
              "slowRendering": { "enabled": true }
            }
          },
          "ios": {
            "instrumentation": {
              "screenLifecycle": { "enabled": true },
              "urlSession":      { "enabled": true },
              "crash":           { "enabled": true }
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
