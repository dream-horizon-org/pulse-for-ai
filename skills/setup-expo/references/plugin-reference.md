# Expo Plugin Reference

Full app.json configuration options for `@dreamhorizonorg/pulse-react-native`.

## Top Level

| Option | Required | Values | Description |
|---|---|---|---|
| `apiKey` | Yes | string | Project API key from Pulse dashboard |
| `dataCollectionState` | Yes | `"ALLOWED"`, `"PENDING"`, `"DENIED"` | Initial data collection consent state |
| `android` | No | object | Android-specific overrides |
| `ios` | No | object | iOS-specific overrides |

## Android Options

| Option | Description |
|---|---|
| `apiKey` | Override API key for Android only |
| `dataCollectionState` | Override consent state for Android only |
| `globalAttributes` | Key/value pairs attached to all Android telemetry |
| `logLevel` | `"VERBOSE"`, `"DEBUG"`, `"INFO"`, `"WARN"`, `"ERROR"`, `"NONE"` — debugging only, remove before release |
| `coreLibraryDesugaring` | `{ "enabled": boolean }` — required when minSdkVersion < 26 |
| `okHttpInstrumentation` | `{ "enabled": boolean }` — native OkHttp spans for Image/FastImage network requests |

**Android instrumentations** (each takes `{ "enabled": boolean }`):
`crash`, `network`, `activity`, `fragment`, `anr`, `slowRendering`, `interaction`

## iOS Options

| Option | Description |
|---|---|
| `apiKey` | Override API key for iOS only |
| `dataCollectionState` | Override consent state for iOS only |
| `globalAttributes` | Key/value pairs attached to all iOS telemetry |
| `logLevel` | `"VERBOSE"`, `"DEBUG"`, `"INFO"`, `"WARN"`, `"ERROR"`, `"NONE"` — debugging only |
| `configuration.includeScreenAttributes` | boolean — attach screen metadata to telemetry |
| `configuration.includeNetworkAttributes` | boolean — attach network metadata |
| `configuration.includeGlobalAttributes` | boolean — attach global attributes |

**iOS instrumentations** (each takes `{ "enabled": boolean }`):
`crash`, `appLifecycle`, `screenLifecycle`, `appStartup`, `location`

## Full Example

```json
{
  "expo": {
    "plugins": [
      [
        "@dreamhorizonorg/pulse-react-native",
        {
          "apiKey": "your-api-key",
          "dataCollectionState": "PENDING",
          "android": {
            "globalAttributes": { "platform": "android" },
            "coreLibraryDesugaring": { "enabled": true },
            "okHttpInstrumentation": { "enabled": true },
            "instrumentation": {
              "crash": { "enabled": true },
              "network": { "enabled": true },
              "fragment": { "enabled": false },
              "interaction": { "enabled": true }
            }
          },
          "ios": {
            "globalAttributes": { "platform": "ios" },
            "configuration": {
              "includeScreenAttributes": true
            },
            "instrumentation": {
              "crash": { "enabled": true },
              "screenLifecycle": { "enabled": false }
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
| `PENDING` | SDK initialized — telemetry buffered in memory, nothing exported until state changes |
| `DENIED` | Terminal — buffer cleared, SDK shuts down. Cannot be undone in the same process. |

**Valid transitions:**
- `PENDING` → `ALLOWED`: flushes buffer, starts exporting
- `PENDING` → `DENIED`: clears buffer, shuts down
- `ALLOWED` → `DENIED`: clears buffer, shuts down
- `DENIED` → anything: invalid — must restart app
